import 'dart:async';

import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/logging/app_logger.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/core/utils/uuid_generator.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/data/mapper/transaction_mapper.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_list_snapshot.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

/// The offline-first half of `TransactionRepository` (W4 T6).
///
/// **The policy lives here**, on the shape `AccountRepositoryImpl` set: the id (`GPUuidGenerator.v7`), the instant (one read of `GPClock` per operation),
/// the owner (never seen by the domain), the mapping, and what a failure means. `TransactionDao` holds none of it. What this repository adds over accounts
/// is two things, each decided in an ADR before it was written:
///
/// - **The rules that need another row run inside the write's own transaction** (ADR-0010): the account — and a transfer's destination — must be live and
///   the owner's, and the amount must be in the account's currency. Checked in the same `transaction {}` as the insert or update, so the background sync
///   of P4 cannot delete the account between the check and the write. They run *before* the version guard of an update: nothing is written that should
///   not be, and a conflict is still reported whenever the accounts are fine.
/// - **A row that will not map does not fail the list** (ADR-0011). It is counted in the snapshot and logged — once per stream, not once per emission: the
///   list re-runs after every write to the table, and one bad row would otherwise repeat the same log line for every edit the user makes.
///
/// No network, for the reason `AccountRepositoryImpl` gives. From W12 T5 every write below also inserts its outbox mutation in the same transaction
/// (golden rule 3) — the two writes that already open one only gain a line inside it.
class TransactionRepositoryImpl implements TransactionRepository {
  const TransactionRepositoryImpl({
    required TransactionDao dao,
    required GPClock clock,
    required GPUuidGenerator uuidGenerator,
    required GPAppLogger logger,
    required String ownerId,
    TransactionMapper mapper = const TransactionMapper(),
  }) : _dao = dao,
       _clock = clock,
       _uuidGenerator = uuidGenerator,
       _logger = logger,
       _ownerId = ownerId,
       _mapper = mapper;

  final TransactionDao _dao;
  final GPClock _clock;
  final GPUuidGenerator _uuidGenerator;
  final GPAppLogger _logger;
  final TransactionMapper _mapper;

  /// `localOwnerId` today; the signed-in uid once auth lands. Stated rather than defaulted, for the reason `AccountRepositoryImpl` gives.
  final String _ownerId;

  @override
  Stream<TransactionListSnapshot> watchTransactions(TransactionQuery query) {
    // One set per stream this call returns. A BLoC re-subscribes when its filter or its window changes, and each new stream logs a refused row once more —
    // which is the moment someone might be looking.
    final logged = <String>{};

    return _dao
        .watchTransactions(
          _ownerId,
          limit: query.limit,
          accountIds: query.accountIds,
          categoryIds: query.categoryIds,
          types: query.types?.map((type) => type.storageValue).toSet(),
          fromMillis: query.from?.millisecondsSinceEpoch,
          toMillis: query.to?.millisecondsSinceEpoch,
        )
        .transform(
          StreamTransformer<List<TransactionRow>, TransactionListSnapshot>.fromHandlers(
            handleData: (rows, sink) {
              final transactions = <TransactionEntity>[];
              var unreadable = 0;

              for (final row in rows) {
                switch (_mapper.toEntity(row)) {
                  case MappedTransaction(:final transaction):
                    transactions.add(transaction);
                  case UnmappableTransactionRow(:final reason):
                    unreadable++;
                    if (logged.add(row.id)) _logRejectedRow(row.id, reason);
                }
              }

              // On the raw row count, refused rows included: a full window with one unreadable row in it must still say there may be more (ADR-0011).
              sink.add(TransactionListSnapshot(transactions: transactions, unreadableCount: unreadable, hasMore: rows.length >= query.limit));
            },
            handleError: (error, stackTrace, sink) => _reportQueryError('transaction list read failed', error, stackTrace, sink),
          ),
        );
  }

  @override
  Stream<TransactionEntity?> watchTransaction(String id) {
    // The same once-per-stream logging as the list, although here every emission still carries the error: one row has no partial answer.
    var logged = false;

    return _dao
        .watchTransaction(_ownerId, id)
        .transform(
          StreamTransformer<TransactionRow?, TransactionEntity?>.fromHandlers(
            handleData: (row, sink) {
              if (row == null) {
                // Not an error: the DAO filters tombstones, so null means "gone" — what an edit screen subscribes in order to learn.
                sink.add(null);
                return;
              }

              switch (_mapper.toEntity(row)) {
                case MappedTransaction(:final transaction):
                  sink.add(transaction);
                case UnmappableTransactionRow(:final reason, :final failure):
                  if (!logged) {
                    logged = true;
                    _logRejectedRow(row.id, reason);
                  }
                  sink.addError(failure);
              }
            },
            handleError: (error, stackTrace, sink) => _reportQueryError('transaction read failed', error, stackTrace, sink, id: id),
          ),
        );
  }

  @override
  Future<GPResult<TransactionEntity>> createTransaction({
    required TransactionType type,
    required String accountId,
    required Money amount,
    required DateTime occurredAt,
    String? destinationAccountId,
    String? categoryId,
    String? note,
  }) async {
    final now = _clock.nowUtc();

    // The entity's own rules first, before the database is touched at all — a blank transfer destination needs no query to be refused.
    final created = TransactionEntity.create(
      id: _uuidGenerator.v7(),
      type: type,
      accountId: accountId,
      destinationAccountId: destinationAccountId,
      categoryId: categoryId,
      amount: amount,
      occurredAt: occurredAt,
      note: note,
      createdAt: now,
      updatedAt: now,
    );

    switch (created) {
      case GPErr<TransactionEntity>():
        return created;
      case GPOk<TransactionEntity>(:final value):
        try {
          return await _dao.transaction(() async {
            final refused = await _refusalFromAccounts(value);
            if (refused != null) return GPErr<TransactionEntity>(refused);

            await _dao.insertTransaction(_mapper.toInsert(value, ownerId: _ownerId));

            // Returned as built, not read back — the caller holds every value that was written, and the stream is what tells the UI.
            return GPOk<TransactionEntity>(value);
          });
        } on Exception catch (error, stackTrace) {
          return _databaseFailure<TransactionEntity>('transaction insert failed', value.id, error, stackTrace);
        }
    }
  }

  @override
  Future<GPResult<TransactionEntity>> updateTransaction(TransactionEntity transaction) async {
    final now = _clock.nowUtc();
    // No validation branch for the entity's own rules: a `TransactionEntity` cannot exist unvalidated (`create` and `update` are the only ways to build
    // one). What is left to decide is *when*, and whether the accounts it names still agree.
    final stamped = transaction.stampedAt(now);

    try {
      return await _dao.transaction(() async {
        final refused = await _refusalFromAccounts(stamped);
        if (refused != null) return GPErr<TransactionEntity>(refused);

        final written = await _dao.updateTransaction(
          stamped.id,
          baseVersion: transaction.version,
          patch: _mapper.toPatch(stamped),
          now: now.millisecondsSinceEpoch,
        );

        if (written == 1) return GPOk<TransactionEntity>(stamped);

        // Zero rows is a stale version, a tombstone, or a row that was never there. Asked inside the transaction, so the answer is still true when it
        // is returned — the reasoning `AccountRepositoryImpl.updateAccount` gives.
        final current = await _dao.findById(stamped.id);

        if (current == null || current.deletedAt != null) return const GPErr<TransactionEntity>(GPNotFoundFailure());

        return GPErr<TransactionEntity>(GPConflictFailure(entityId: stamped.id, localVersion: transaction.version, remoteVersion: current.version));
      });
    } on Exception catch (error, stackTrace) {
      return _databaseFailure<TransactionEntity>('transaction update failed', stamped.id, error, stackTrace);
    }
  }

  @override
  Future<GPResult<void>> deleteTransaction(String id) async {
    // No account rule: a transaction on an account that is already gone must still be deletable — it is the only way to clean one up.
    try {
      final written = await _dao.softDelete(id, now: _clock.nowEpochMillis());

      if (written == 0) return const GPErr<void>(GPNotFoundFailure());

      return const GPOk<void>(null);
    } on Exception catch (error, stackTrace) {
      return _databaseFailure<void>('transaction delete failed', id, error, stackTrace);
    }
  }

  /// The two rules of ADR-0010 that need another row, or null when the write may go ahead. Called only inside the write's own transaction.
  ///
  /// The account must be live and the owner's — archived counts, deleted does not — or the answer is [GPNotFoundFailure]. The amount must be in its
  /// currency, or [GPValidationCode.transactionCurrencyMismatch]. A transfer's destination must pass the same first test and keep the same currency, or
  /// [GPValidationCode.transactionTransferCurrenciesDiffer]: two different sentences, because the user has two different things to fix.
  Future<GPFailure?> _refusalFromAccounts(TransactionEntity transaction) async {
    final currency = await _dao.liveAccountCurrency(_ownerId, transaction.accountId);
    if (currency == null) return const GPNotFoundFailure();
    if (currency != transaction.amount.currencyCode) return const GPValidationFailure(GPValidationCode.transactionCurrencyMismatch);

    final destinationId = transaction.destinationAccountId;
    if (destinationId == null) return null;

    final destinationCurrency = await _dao.liveAccountCurrency(_ownerId, destinationId);
    if (destinationCurrency == null) return const GPNotFoundFailure();
    if (destinationCurrency != currency) return const GPValidationFailure(GPValidationCode.transactionTransferCurrenciesDiffer);

    return null;
  }

  /// Logs a row the mapper refused: an id, an entity type and a reason — the three things golden rule 9 allows. The amount and the note are in scope at
  /// every call site and neither is logged.
  void _logRejectedRow(String id, TransactionMapperReason reason) =>
      _logger.error('transaction row could not be mapped', fields: {'entity': 'transaction', 'id': id, 'reason': reason.name});

  /// Logs a local-storage failure and reports it as one. `on Exception` at every call site, never `on Object`, for the line `AccountRepositoryImpl` draws:
  /// an `Error` is a bug, and it must reach the crash reporter rather than a sentence the user can do nothing with.
  GPResult<T> _databaseFailure<T>(String message, String id, Object error, StackTrace stackTrace) {
    _logger.error(message, fields: {'entity': 'transaction', 'id': id}, error: error, stackTrace: stackTrace);

    return GPErr<T>(const GPDatabaseFailure());
  }

  /// Puts what a watched query raised back on its stream: a logged [GPDatabaseFailure] for an [Exception], the original object for anything else —
  /// `AccountRepositoryImpl._reportQueryError`, line for line, so both features keep the one promise their interfaces make about the error channel.
  void _reportQueryError<T>(String message, Object error, StackTrace stackTrace, EventSink<T> sink, {String? id}) {
    if (error is! Exception) {
      sink.addError(error, stackTrace);
      return;
    }

    _logger.error(message, fields: {'entity': 'transaction', 'id': ?id}, error: error, stackTrace: stackTrace);
    sink.addError(const GPDatabaseFailure());
  }
}
