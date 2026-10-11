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
                  case MappedAccount(:final account):
                    entities.add(account);
                  case UnmappableAccountRow(:final reason, :final failure):
                    // The whole list fails rather than silently dropping an account; transactions decide differently (ADR-0006, ADR-0011).
                    _logRejectedRow(row.id, reason);
                    sink.addError(failure);
                    return;
                }
              }

              sink.add(entities);
            },
            handleError: (error, stackTrace, sink) => _reportQueryError('account list read failed', error, stackTrace, sink),
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
                sink.add(null);
                return;
              }

              switch (_mapper.toEntity(row)) {
                case MappedAccount(:final account):
                  sink.add(account);
                case UnmappableAccountRow(:final reason, :final failure):
                  _logRejectedRow(row.id, reason);
                  sink.addError(failure);
              }
            },
            handleError: (error, stackTrace, sink) => _reportQueryError('account read failed', error, stackTrace, sink, id: id),
          ),
        );
  }

  @override
  Future<GPResult<AccountEntity>> createAccount({required String name, required AccountType type, required Money initialBalance}) async {
    final now = _clock.nowUtc();

    final created = AccountEntity.create(id: _uuidGenerator.v7(), name: name, type: type, initialBalance: initialBalance, createdAt: now, updatedAt: now);

    switch (created) {
      case GPErr<AccountEntity>():
        return created;
      case GPOk<AccountEntity>(:final value):
        try {
          await _dao.insertAccount(_mapper.toInsert(value, ownerId: _ownerId));
          return GPOk<AccountEntity>(value);
        } on Exception catch (error, stackTrace) {
          return _databaseFailure<AccountEntity>('account insert failed', value.id, error, stackTrace);
        }
    }
  }

  @override
  Future<GPResult<AccountEntity>> updateAccount(AccountEntity account) async {
    final now = _clock.nowUtc();
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

        // Zero rows: a conflict, or no live row. Re-read inside the transaction, so a delete cannot land between the write and the lookup.
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

  /// Unguarded writes: zero rows can only mean no live row, so unlike [updateAccount] there is nothing to re-read.
  Future<GPResult<void>> _write(String id, String failureMessage, Future<int> Function(int now) write) async {
    try {
      final written = await write(_clock.nowEpochMillis());

      if (written == 0) return const GPErr<void>(GPNotFoundFailure());

      return const GPOk<void>(null);
    } on Exception catch (error, stackTrace) {
      return _databaseFailure<void>(failureMessage, id, error, stackTrace);
    }
  }

  void _logRejectedRow(String id, AccountMapperReason reason) => _logger.error('account row could not be mapped', fields: {'entity': 'account', 'id': id, 'reason': reason.name});

  /// For `on Exception` catches only: an `Error` is a bug and must not be dressed up as a failure (ADR-0006).
  GPResult<T> _databaseFailure<T>(String message, String id, Object error, StackTrace stackTrace) {
    _logger.error(message, fields: {'entity': 'account', 'id': id}, error: error, stackTrace: stackTrace);

    return GPErr<T>(const GPDatabaseFailure());
  }

  /// An [Exception] is the database refusing: logged and replaced by a [GPDatabaseFailure]. Anything else is a bug, forwarded untouched for the crash
  /// reporter. Errors from drift's background isolate arrive as a `DriftRemoteException`, so even a bug raised there lands as a failure.
  void _reportQueryError<T>(String message, Object error, StackTrace stackTrace, EventSink<T> sink, {String? id}) {
    if (error is! Exception) {
      sink.addError(error, stackTrace);
      return;
    }

    _logger.error(message, fields: {'entity': 'account', 'id': ?id}, error: error, stackTrace: stackTrace);
    sink.addError(const GPDatabaseFailure());
  }
}
