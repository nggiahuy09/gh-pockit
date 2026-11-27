import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/database/owner_id.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/money/money.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transaction_sync_status.dart';
import '../../domain/entities/transaction_type.dart';
import '../daos/transaction_dao.dart';

sealed class TransactionMapping {
  const TransactionMapping();
}

final class MappedTransaction extends TransactionMapping {
  const MappedTransaction(this.transaction);

  final TransactionEntity transaction;
}

final class UnmappableTransactionRow extends TransactionMapping {
  const UnmappableTransactionRow(this.reason);

  final TransactionMapperReason reason;

  GPFailure get failure => const GPDatabaseFailure();
}

extension TransactionRowMapper on TransactionRow {
  /// Maps a tombstone like a live row: `TransactionDao.findById` wants them.
  TransactionMapping toDomain() {
    final transactionType = TransactionType.fromStorage(type);
    if (transactionType == null) return const UnmappableTransactionRow(TransactionMapperReason.unknownType);

    // Not the throwing `Money(...)`: a malformed code read from SQLite is data, not a bug (ADR-0006).
    final amount = Money.fromStorage(amountMinor, currencyCode);
    if (amount == null) return const UnmappableTransactionRow(TransactionMapperReason.malformedCurrencyCode);

    // A `'local'` row is `pending` in the column, but nothing pushes it until a claim (ADR-0045).
    final status = ownerId == localOwnerId
        ? TransactionSyncStatus.localOnly
        : switch (syncStatus) {
            TransactionDao.pendingSyncStatus => TransactionSyncStatus.pending,
            TransactionDao.syncedSyncStatus => TransactionSyncStatus.synced,
            _ => null,
          };
    if (status == null) return const UnmappableTransactionRow(TransactionMapperReason.unknownSyncStatus);

    final entity = TransactionEntity.create(
      amount: amount,
      type: transactionType,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true),
      occurredAt: DateTime.fromMillisecondsSinceEpoch(occurredAt, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt, isUtc: true),
      accountId: accountId,
      categoryId: categoryId,
      destinationAccountId: destinationAccountId,
      id: id,
      note: note,
      version: version,
      syncStatus: status,
    );

    return switch (entity) {
      GPOk(:final value) => MappedTransaction(value),
      GPErr() => const UnmappableTransactionRow(TransactionMapperReason.brokenDomainRule),
    };
  }
}

extension TransactionEntityMapper on TransactionEntity {
  /// `.insert`, so a new non-null column is a compile error here until it is set.
  TransactionsTableCompanion toInsert(String ownerId) => TransactionsTableCompanion.insert(
    id: id,
    ownerId: ownerId,
    type: type.storageValue,
    accountId: accountId,
    destinationAccountId: Value(destinationAccountId),
    categoryId: Value(categoryId),
    amountMinor: amount.minorUnits,
    currencyCode: amount.currencyCode,
    occurredAt: occurredAt.millisecondsSinceEpoch,
    note: Value(note),
    createdAt: createdAt.millisecondsSinceEpoch,
    updatedAt: updatedAt.millisecondsSinceEpoch,
    version: version,
    syncStatus: TransactionDao.pendingSyncStatus,
  );

  /// Null references are written as `Value(null)`, not left absent: switching the type must clear the old destination or category, or the table's CHECK
  /// refuses the row.
  TransactionsTableCompanion toPatch() => TransactionsTableCompanion(
    type: Value(type.storageValue),
    accountId: Value(accountId),
    destinationAccountId: Value(destinationAccountId),
    categoryId: Value(categoryId),
    amountMinor: Value(amount.minorUnits),
    currencyCode: Value(amount.currencyCode),
    occurredAt: Value(occurredAt.millisecondsSinceEpoch),
    note: Value(note),
  );
}

extension TransactionRowSyncPayload on TransactionRow {
  /// The row as the server's `transactions` names it (ADR-0033): every column but `sync_status`, which the server does not have.
  Map<String, Object?> toSyncPayload() => {
    'id': id,
    'owner_id': ownerId,
    'type': type,
    'account_id': accountId,
    'destination_account_id': destinationAccountId,
    'category_id': categoryId,
    'amount_minor': amountMinor,
    'currency_code': currencyCode,
    'occurred_at': occurredAt,
    'note': note,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'version': version,
    'deleted_at': deletedAt,
  };
}

/// Goes to the log, so a reason names a check and never a value from the row (golden rule 9).
enum TransactionMapperReason {
  unknownType,
  unknownSyncStatus,

  malformedCurrencyCode,
  brokenDomainRule,
}
