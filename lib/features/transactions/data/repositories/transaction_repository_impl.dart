import 'dart:async';

import '../../../../core/database/database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/uuid_generator.dart';
import '../../../accounts/data/mapper/account_mapper.dart';
import '../../../accounts/domain/entities/account_balance.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transaction_list_snapshot.dart';
import '../../domain/entities/transaction_query.dart';
import '../../domain/entities/transaction_type.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../daos/transaction_dao.dart';
import '../mapper/transaction_mapper.dart';

/// Account rules run inside the write's own transaction, so sync cannot delete the account between check and write (ADR-0010).
final class TransactionRepositoryImpl implements TransactionRepository {
  const TransactionRepositoryImpl({
    required GPClock clock,
    required TransactionDao dao,
    required GPAppLogger logger,
    required GPUuidGenerator uuidGenerator,
    required String ownerId,
  }) : _clock = clock,
       _dao = dao,
       _logger = logger,
       _uuidGenerator = uuidGenerator,
       _ownerId = ownerId;

  final GPClock _clock;
  final TransactionDao _dao;
  final GPAppLogger _logger;
  final GPUuidGenerator _uuidGenerator;
  final String _ownerId;

  @override
  Stream<TransactionListSnapshot> watchTransactions(TransactionQuery query) {
    // Per stream, not per emission: the list re-runs after every write, and one bad row would log on every edit.
    final logged = <String>{};

    return _dao
        .watchTransactions(
          _ownerId,
          accountIds: query.accountIds,
          categoryIds: query.categoryIds,
          types: query.types?.map((type) => type.storageValue).toSet(),
          fromMillis: query.from?.millisecondsSinceEpoch,
          limit: query.limit,
          toMillis: query.to?.millisecondsSinceEpoch,
        )
        .transform(
          StreamTransformer<List<TransactionRow>, TransactionListSnapshot>.fromHandlers(
            handleData: (rows, sink) {
              final transactions = <TransactionEntity>[];
              var unreadable = 0;
              for (final row in rows) {
                switch (row.toDomain()) {
                  case MappedTransaction(:final transaction):
                    transactions.add(transaction);
                  case UnmappableTransactionRow(:final reason):
                    unreadable++;
                    if (logged.add(row.id)) _logRejectedRow(reason, row.id);
                }
              }

              // Raw row count, refused rows included: a full window with one unreadable row may still have more (ADR-0011).
              sink.add(TransactionListSnapshot(transactions: transactions, unreadableCount: unreadable, hasMore: rows.length >= query.limit));
            },
            handleError: (error, stackTrace, sink) => _reportQueryError(error: error, sink: sink, stackTrace: stackTrace, message: 'transaction list read failed'),
          ),
        );
  }

  @override
  Stream<TransactionEntity?> watchTransaction(String id) {
    var logged = false;

    return _dao
        .watchTransaction(id: id, ownerId: _ownerId)
        .transform(
          StreamTransformer<TransactionRow?, TransactionEntity?>.fromHandlers(
            handleData: (row, sink) {
              if (row == null) {
                sink.add(null);
                return;
              }

              switch (row.toDomain()) {
                case MappedTransaction(:final transaction):
                  sink.add(transaction);
                case UnmappableTransactionRow(:final reason, :final failure):
                  if (!logged) {
                    logged = true;
                    _logRejectedRow(reason, row.id);
                  }
                  sink.addError(failure);
              }
            },
            handleError: (error, stackTrace, sink) => _reportQueryError(error: error, sink: sink, stackTrace: stackTrace, id: id, message: 'transaction read failed'),
          ),
        );
  }

  @override
  Future<GPResult<TransactionEntity>> createTransaction({
    required Money amount,
    required TransactionType type,
    required DateTime occurredAt,
    required String accountId,
    String? categoryId,
    String? destinationAccountId,
    String? note,
  }) async {
    final now = _clock.nowUtc();
    final created = TransactionEntity.create(
      amount: amount,
      type: type,
      createdAt: now,
      occurredAt: occurredAt,
      updatedAt: now,
      accountId: accountId,
      categoryId: categoryId,
      destinationAccountId: destinationAccountId,
      id: _uuidGenerator.v7(),
      note: note,
    );

    switch (created) {
      case GPErr():
        return created;
      case GPOk(:final value):
        try {
          return await _dao.transaction(() async {
            final refused = await _refusalFromAccounts(accountId: value.accountId, currencyCode: value.amount.currencyCode, destinationAccountId: value.destinationAccountId);
            if (refused != null) return GPErr(refused);

            await _dao.insertTransaction(value.toInsert(_ownerId));
            return GPOk(value);
          });
        } on Exception catch (error, stackTrace) {
          return _databaseFailure(error: error, stackTrace: stackTrace, id: value.id, message: 'transaction insert failed');
        }
    }
  }

  @override
  Future<GPResult<TransactionEntity>> updateTransaction(TransactionEntity transaction) async {
    final now = _clock.nowUtc();
    final stamped = transaction.withUpdatedAt(now);

    try {
      return await _dao.transaction(() async {
        final refused = await _refusalFromAccounts(accountId: stamped.accountId, currencyCode: stamped.amount.currencyCode, destinationAccountId: stamped.destinationAccountId);
        if (refused != null) return GPErr(refused);

        final written = await _dao.updateTransaction(stamped.id, patch: stamped.toPatch(), baseVersion: transaction.version, now: now.millisecondsSinceEpoch);
        if (written == 1) return GPOk(stamped);

        // 0 rows: a stale version, a tombstone, or no row. Asked inside the transaction, so the answer still holds when it is returned.
        final current = await _dao.findById(stamped.id);
        if (current == null || current.deletedAt != null) return const GPErr(GPNotFoundFailure());

        return GPErr(GPConflictFailure(entityId: stamped.id, localVersion: transaction.version, remoteVersion: current.version));
      });
    } on Exception catch (error, stackTrace) {
      return _databaseFailure(error: error, stackTrace: stackTrace, id: stamped.id, message: 'transaction update failed');
    }
  }

  @override
  Future<GPResult<void>> deleteTransaction(String id) async {
    try {
      final written = await _dao.softDelete(id, now: _clock.nowEpochMillis());
      if (written == 0) return const GPErr(GPNotFoundFailure());

      return const GPOk(null);
    } on Exception catch (error, stackTrace) {
      return _databaseFailure(error: error, stackTrace: stackTrace, id: id, message: 'transaction delete failed');
    }
  }

  @override
  Future<GPResult<void>> restoreTransaction(String id) async {
    try {
      return await _dao.transaction(() async {
        final row = await _dao.findById(id);
        if (row == null || row.ownerId != _ownerId || row.deletedAt == null) return const GPErr(GPNotFoundFailure());

        // From the row, not a mapped entity: coming back must hold the account rule as a new row does.
        final refused = await _refusalFromAccounts(accountId: row.accountId, currencyCode: row.currencyCode, destinationAccountId: row.destinationAccountId);
        if (refused != null) return GPErr(refused);

        await _dao.restore(id, now: _clock.nowEpochMillis());
        return const GPOk(null);
      });
    } on Exception catch (error, stackTrace) {
      return _databaseFailure(error: error, stackTrace: stackTrace, id: id, message: 'transaction restore failed');
    }
  }

  @override
  Future<GPResult<bool>> hasLiveTransactions(String accountId) async {
    try {
      return GPOk(await _dao.hasLiveTransactions(accountId: accountId, ownerId: _ownerId));
    } on Exception catch (error, stackTrace) {
      return _databaseFailure(error: error, stackTrace: stackTrace, entity: 'account', id: accountId, message: 'transaction lookup by account failed');
    }
  }

  @override
  Stream<List<AccountBalance>> watchAccountBalances() {
    return _dao
        .watchAccountBalances(_ownerId)
        .transform(
          StreamTransformer<List<({AccountRow account, int balanceMinor})>, List<AccountBalance>>.fromHandlers(
            handleData: (rows, sink) {
              final balances = <AccountBalance>[];
              for (final row in rows) {
                switch (row.account.toDomain()) {
                  case MappedAccount(:final account):
                    balances.add(AccountBalance(account: account, balance: Money(row.balanceMinor, account.initialBalance.currencyCode)));
                  case UnmappableAccountRow(:final reason, :final failure):
                    // The whole list fails, as `watchAccounts` does: a total with an account silently missing is worse than an error.
                    _logger.error('account row could not be mapped', fields: {'entity': 'account', 'id': row.account.id, 'reason': reason.name});
                    sink.addError(failure);
                    return;
                }
              }

              sink.add(balances);
            },
            handleError: (error, stackTrace, sink) =>
                _reportQueryError(error: error, sink: sink, stackTrace: stackTrace, entity: 'account', message: 'account balances read failed'),
          ),
        );
  }

  /// Null when the write may go ahead. Call only inside the write's transaction.
  Future<GPFailure?> _refusalFromAccounts({required String accountId, required String currencyCode, required String? destinationAccountId}) async {
    final currency = await _dao.liveAccountCurrency(accountId: accountId, ownerId: _ownerId);
    if (currency == null) return const GPNotFoundFailure();
    if (currency != currencyCode) return const GPValidationFailure(GPValidationCode.transactionCurrencyMismatch);

    if (destinationAccountId == null) return null;

    final destinationCurrency = await _dao.liveAccountCurrency(accountId: destinationAccountId, ownerId: _ownerId);
    if (destinationCurrency == null) return const GPNotFoundFailure();
    if (destinationCurrency != currency) return const GPValidationFailure(GPValidationCode.transactionTransferCurrenciesDiffer);

    return null;
  }

  void _logRejectedRow(TransactionMapperReason reason, String id) =>
      _logger.error('transaction row could not be mapped', fields: {'entity': 'transaction', 'id': id, 'reason': reason.name});

  /// For `on Exception` catches only: an `Error` is a bug and must reach the crash reporter (ADR-0006).
  GPResult<T> _databaseFailure<T>({required Object error, required StackTrace stackTrace, String entity = 'transaction', required String id, required String message}) {
    _logger.error(message, fields: {'entity': entity, 'id': id}, error: error, stackTrace: stackTrace);

    return GPErr<T>(const GPDatabaseFailure());
  }

  /// Anything but an [Exception] is a bug and passes through.
  void _reportQueryError<T>({
    required Object error,
    required EventSink<T> sink,
    required StackTrace stackTrace,
    String entity = 'transaction',
    String? id,
    required String message,
  }) {
    if (error is! Exception) {
      sink.addError(error, stackTrace);
      return;
    }

    _logger.error(message, fields: {'entity': entity, 'id': ?id}, error: error, stackTrace: stackTrace);
    sink.addError(const GPDatabaseFailure());
  }
}
