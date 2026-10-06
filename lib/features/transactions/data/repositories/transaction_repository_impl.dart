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

/// Account rules run inside the write's own transaction, so sync cannot delete the account between check and write (ADR-0010). A row that will not map is
/// counted in the snapshot rather than failing the list (ADR-0011).
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
  final String _ownerId;

  @override
  Stream<TransactionListSnapshot> watchTransactions(TransactionQuery query) {
    // Per stream, not per emission: the list re-runs after every write, and one bad row would log on every edit.
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

              // Raw row count, refused rows included: a full window with one unreadable row may still have more (ADR-0011).
              sink.add(TransactionListSnapshot(transactions: transactions, unreadableCount: unreadable, hasMore: rows.length >= query.limit));
            },
            handleError: (error, stackTrace, sink) => _reportQueryError('transaction list read failed', error, stackTrace, sink),
          ),
        );
  }

  @override
  Stream<TransactionEntity?> watchTransaction(String id) {
    var logged = false;

    return _dao
        .watchTransaction(_ownerId, id)
        .transform(
          StreamTransformer<TransactionRow?, TransactionEntity?>.fromHandlers(
            handleData: (row, sink) {
              if (row == null) {
                // Not an error: the DAO filters tombstones, so null means the row is gone.
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

            // Returned as built, not read back: the stream is what tells the UI.
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
    // No entity validation here: a `TransactionEntity` cannot exist unvalidated.
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

        // 0 rows: a stale version, a tombstone, or no row. Asked inside the transaction, so the answer still holds when it is returned.
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
    // No account rule: a transaction on an account that is already gone must still be deletable.
    try {
      final written = await _dao.softDelete(id, now: _clock.nowEpochMillis());

      if (written == 0) return const GPErr<void>(GPNotFoundFailure());

      return const GPOk<void>(null);
    } on Exception catch (error, stackTrace) {
      return _databaseFailure<void>('transaction delete failed', id, error, stackTrace);
    }
  }

  @override
  Future<GPResult<bool>> hasLiveTransactions(String accountId) async {
    try {
      return GPOk<bool>(await _dao.hasLiveTransactions(_ownerId, accountId));
    } on Exception catch (error, stackTrace) {
      return _databaseFailure<bool>('transaction lookup by account failed', accountId, error, stackTrace, entity: 'account');
    }
  }

  /// Null when the write may go ahead. Call only inside the write's transaction. Two currency codes, because the user has two different things to fix.
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

  /// Id, entity and reason only (golden rule 9): the amount and the note are in scope and must stay out.
  void _logRejectedRow(String id, TransactionMapperReason reason) =>
      _logger.error('transaction row could not be mapped', fields: {'entity': 'transaction', 'id': id, 'reason': reason.name});

  /// Call sites catch `on Exception`, never `on Object`: an `Error` is a bug and must reach the crash reporter.
  GPResult<T> _databaseFailure<T>(String message, String id, Object error, StackTrace stackTrace, {String entity = 'transaction'}) {
    _logger.error(message, fields: {'entity': entity, 'id': id}, error: error, stackTrace: stackTrace);

    return GPErr<T>(const GPDatabaseFailure());
  }

  /// An [Exception] becomes a logged [GPDatabaseFailure], the only error the interface promises on the channel; anything else is a bug and passes through.
  void _reportQueryError<T>(String message, Object error, StackTrace stackTrace, EventSink<T> sink, {String? id}) {
    if (error is! Exception) {
      sink.addError(error, stackTrace);
      return;
    }

    _logger.error(message, fields: {'entity': 'transaction', 'id': ?id}, error: error, stackTrace: stackTrace);
    sink.addError(const GPDatabaseFailure());
  }
}
