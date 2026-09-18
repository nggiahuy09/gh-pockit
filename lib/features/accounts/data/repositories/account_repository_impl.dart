import 'dart:async';

import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/logging/app_logger.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/core/utils/uuid_generator.dart';
import 'package:ghpockit/features/accounts/data/daos/account_dao.dart';
import 'package:ghpockit/features/accounts/data/mapper/account_mapper.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';

/// The offline-first half of `AccountRepository` (W2 T6).
///
/// **This is where the policy lives**, and naming it is the difference between a repository and the pass-through §12.2 rejects. `AccountDao` deliberately
/// holds no clock, no id generator and no opinion; this class supplies all three, so exactly one layer decides:
///
/// - **the id**, minted by `GPUuidGenerator.v7` before the row exists (golden rule 4, ADR-0002) — never handed back by a server;
/// - **the instant**, read from `GPClock` **once per operation** and passed everywhere that operation writes. From W7 that same instant also lands on the
///   `sync_mutations` row written in the same transaction (golden rule 3), so the entity and its mutation describe one moment rather than two;
/// - **the owner**, which the domain never sees (see `AccountRepository`);
/// - **what a failure means**: zero rows written is a conflict, or a tombstone, or a row that was never there, and only this layer can tell them apart.
///
/// **No network, on purpose.** Nothing here asks whether the device is online, and nothing here talks to a server: a write goes to SQLite and returns, and
/// the sync engine of P4 pushes it afterwards from the outbox. That is why `GPNetworkFailure` cannot come out of any method below, and why there is no
/// `bool isOnline` branching between a local and a remote path (§12.5) — the local path is the only path.
///
/// **What W7 adds, and where.** Every write below becomes a transaction containing the entity write *and* an outbox insert. [updateAccount] already opens
/// one for a different reason, which is a useful rehearsal: the shape does not change, only what goes inside the block.
class AccountRepositoryImpl implements AccountRepository {
  const AccountRepositoryImpl({
    required AccountDao dao,
    required GPClock clock,
    required GPUuidGenerator uuidGenerator,
    required GPAppLogger logger,
    required String ownerId,
    AccountMapper mapper = const AccountMapper(),
  }) : _dao = dao,
       _clock = clock,
       _uuidGenerator = uuidGenerator,
       _logger = logger,
       _ownerId = ownerId,
       _mapper = mapper;

  final AccountDao _dao;
  final GPClock _clock;
  final GPUuidGenerator _uuidGenerator;
  final GPAppLogger _logger;
  final AccountMapper _mapper;

  /// `localOwnerId` today; the signed-in uid from W10.
  ///
  /// A constructor argument rather than something read per call, because nothing can change it yet. W10 turns this into a session lookup — and the reason
  /// it is stated here instead of defaulted is that `grep localOwnerId` then finds the seam in one hop.
  final String _ownerId;

  @override
  Stream<List<AccountEntity>> watchAccounts({bool includeArchived = false}) {
    return _dao
        .watchAccounts(_ownerId, includeArchived: includeArchived)
        .transform(
          StreamTransformer<List<AccountRow>, List<AccountEntity>>.fromHandlers(
            handleData: (rows, sink) {
              final entities = <AccountEntity>[];

              for (final row in rows) {
                switch (_mapper.toEntity(row)) {
                  case GPOk<AccountEntity>(:final value):
                    entities.add(value);
                  case GPErr<AccountEntity>(:final failure):
                    // **The whole list fails, rather than the bad row being skipped.** Skipping would drop an account from the user's list silently, and a
                    // balance that is quietly missing one account is worse than a screen that says it could not read local data. Golden rule 1 leaves no
                    // remote copy to reconcile against, so a row that will not parse is a real problem and has to look like one.
                    _logger.error('account row could not be mapped', fields: {'entity': 'account', 'id': row.id});
                    sink.addError(failure);
                    return;
                }
              }

              sink.add(entities);
            },
          ),
        );
  }

  @override
  Stream<AccountEntity?> watchAccount(String id) {
    return _dao
        .watchAccount(_ownerId, id)
        .transform(
          StreamTransformer<AccountRow?, AccountEntity?>.fromHandlers(
            handleData: (row, sink) {
              if (row == null) {
                // Not an error: the DAO filters tombstones, so null means "gone", which is what a detail screen subscribes in order to learn.
                sink.add(null);
                return;
              }

              switch (_mapper.toEntity(row)) {
                case GPOk<AccountEntity>(:final value):
                  sink.add(value);
                case GPErr<AccountEntity>(:final failure):
                  _logger.error('account row could not be mapped', fields: {'entity': 'account', 'id': row.id});
                  sink.addError(failure);
              }
            },
          ),
        );
  }

  @override
  Future<GPResult<AccountEntity>> createAccount({required String name, required AccountType type, required Money initialBalance}) async {
    // One read of the clock for the whole operation — `created_at` and `updated_at` must be the same instant on a fresh row, and from W7 the outbox
    // mutation joins them.
    final now = _clock.nowUtc();

    // Validation runs before the row is built, so a blank name never reaches SQLite. The id is minted first and simply goes unused when validation fails;
    // v7's counter tolerates a gap, and the alternative — duplicating the name rule here to avoid burning one — is the thing the domain exists to prevent.
    final created = AccountEntity.create(id: _uuidGenerator.v7(), name: name, type: type, initialBalance: initialBalance, createdAt: now, updatedAt: now);

    switch (created) {
      case GPErr<AccountEntity>():
        return created;
      case GPOk<AccountEntity>(:final value):
        try {
          await _dao.insertAccount(_mapper.toInsert(value, ownerId: _ownerId));
          // The entity is returned as built rather than read back: the caller already holds every value that was written (golden rule 4 again), and the
          // stream from `watchAccounts` is what tells the UI, not this return value.
          return GPOk<AccountEntity>(value);
        } on Exception catch (error, stackTrace) {
          return _databaseFailure<AccountEntity>('account insert failed', value.id, error, stackTrace);
        }
    }
  }

  @override
  Future<GPResult<AccountEntity>> updateAccount(AccountEntity account) async {
    final now = _clock.nowUtc();
    // **No validation branch here, and that is not an omission.** An `AccountEntity` cannot exist unvalidated — `create` is the only way to build one and
    // `update` is the only way to change one, and both refuse a broken name. So a form's validation failure has already been shown to the user, under the
    // field, before this method is reachable. All that is left for the repository to decide is *when*, which is what `stampedAt` says.
    final stamped = account.stampedAt(now);

    try {
      return await _dao.transaction(() async {
        final written = await _dao.updateAccount(
          stamped.id,
          baseVersion: account.version,
          patch: _mapper.toPatch(stamped),
          now: now.millisecondsSinceEpoch,
        );

        if (written == 1) return GPOk<AccountEntity>(stamped);

        // Zero rows is three different situations and the guarded UPDATE cannot tell them apart, so this asks. **Inside the transaction**, because the
        // answer is only true if nothing moved between the write and the lookup — outside it, a concurrent delete would make this report a conflict
        // against a row that is already gone.
        //
        // `findById` is the one read that sees tombstones, which is exactly what is needed here: a soft-deleted row must read as "not found" and not as
        // "never existed", and both must read differently from "somebody else edited it".
        final current = await _dao.findById(stamped.id);

        if (current == null || current.deletedAt != null) {
          return const GPErr<AccountEntity>(GPNotFoundFailure());
        }

        return GPErr<AccountEntity>(
          GPConflictFailure(entityId: stamped.id, localVersion: account.version, remoteVersion: current.version),
        );
      });
    } on Exception catch (error, stackTrace) {
      return _databaseFailure<AccountEntity>('account update failed', stamped.id, error, stackTrace);
    }
  }

  @override
  Future<GPResult<void>> archiveAccount(String id) => _write(id, 'account archive failed', (now) => _dao.archive(id, now: now));

  @override
  Future<GPResult<void>> unarchiveAccount(String id) => _write(id, 'account unarchive failed', (now) => _dao.unarchive(id, now: now));

  @override
  Future<GPResult<void>> deleteAccount(String id) => _write(id, 'account delete failed', (now) => _dao.softDelete(id, now: now));

  /// The three unguarded writes, which differ only in which DAO method they call and what to say when it throws.
  ///
  /// None of them takes a `baseVersion`: archiving and deleting are idempotent and terminal respectively, so a stale version costs nothing and refusing on
  /// one would only make the user press the button twice. Zero rows written therefore has a single meaning — there is no live row with that id — which is
  /// why this does not need [updateAccount]'s follow-up lookup.
  Future<GPResult<void>> _write(String id, String failureMessage, Future<int> Function(int now) write) async {
    try {
      final written = await write(_clock.nowEpochMillis());

      if (written == 0) return const GPErr<void>(GPNotFoundFailure());

      return const GPOk<void>(null);
    } on Exception catch (error, stackTrace) {
      return _databaseFailure<void>(failureMessage, id, error, stackTrace);
    }
  }

  /// Logs a local-storage failure and reports it as one.
  ///
  /// `on Exception`, never `on Object`: a sqlite error, a closed database and a disk that is full all arrive as exceptions, while an `Error` is a bug in
  /// this code — a null that should not be null, a broken invariant — and swallowing it into "could not read local data" would hide it behind a message the
  /// user can do nothing about. Same line `GPDriftLocaleStore` draws, and the same one ADR-0006 draws for the domain.
  ///
  /// The fields carry an id and an entity type and nothing else (golden rule 9). The name of the account, its balance and its currency are all in scope at
  /// every call site and none of them is logged.
  GPResult<T> _databaseFailure<T>(String message, String id, Object error, StackTrace stackTrace) {
    _logger.error(message, fields: {'entity': 'account', 'id': id}, error: error, stackTrace: stackTrace);

    // Not `const`: a type parameter cannot appear in a constant expression, so only the failure itself is canonicalised.
    return GPErr<T>(const GPDatabaseFailure());
  }
}
