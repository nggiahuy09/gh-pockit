import 'package:drift/drift.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

/// Names the check that refused a row, never a value — all a log line may carry (golden rule 9).
enum TransactionMapperReason {
  /// The column has no vocabulary CHECK (ADR-0009), so an unknown type — from a newer build, say — is caught here.
  unknownType,

  malformedCurrencyCode,

  /// E.g. a note longer than this build accepts, written by a build with a larger limit.
  brokenDomainRule,
}

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

  /// Always [GPDatabaseFailure], whatever the reason. The list counts such rows instead of failing (ADR-0011).
  GPFailure get failure => const GPDatabaseFailure();
}

class TransactionMapper {
  const TransactionMapper();

  /// Tombstones are not filtered here: `TransactionDao.findById` wants them.
  TransactionMapping toEntity(TransactionRow row) {
    final type = TransactionType.fromStorage(row.type);
    if (type == null) return const UnmappableTransactionRow(TransactionMapperReason.unknownType);

    // `Money.fromStorage`, not the throwing `Money(...)`: a malformed code read from SQLite is data, not a bug (ADR-0006).
    final amount = Money.fromStorage(row.amountMinor, row.currencyCode);
    if (amount == null) return const UnmappableTransactionRow(TransactionMapperReason.malformedCurrencyCode);

    final entity = TransactionEntity.create(
      id: row.id,
      type: type,
      accountId: row.accountId,
      destinationAccountId: row.destinationAccountId,
      categoryId: row.categoryId,
      amount: amount,
      occurredAt: DateTime.fromMillisecondsSinceEpoch(row.occurredAt, isUtc: true),
      note: row.note,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
      version: row.version,
    );

    return switch (entity) {
      GPOk<TransactionEntity>(:final value) => MappedTransaction(value),
      GPErr<TransactionEntity>() => const UnmappableTransactionRow(TransactionMapperReason.brokenDomainRule),
    };
  }

  /// Through `.insert`, so a column added to the table without a value here is a compile error.
  TransactionsTableCompanion toInsert(TransactionEntity entity, {required String ownerId}) => TransactionsTableCompanion.insert(
    id: entity.id,
    ownerId: ownerId,
    type: entity.type.storageValue,
    accountId: entity.accountId,
    destinationAccountId: Value(entity.destinationAccountId),
    categoryId: Value(entity.categoryId),
    amountMinor: entity.amount.minorUnits,
    currencyCode: entity.amount.currencyCode,
    occurredAt: entity.occurredAt.millisecondsSinceEpoch,
    note: Value(entity.note),
    createdAt: entity.createdAt.millisecondsSinceEpoch,
    updatedAt: entity.updatedAt.millisecondsSinceEpoch,
    version: entity.version,
    syncStatus: TransactionDao.pendingSyncStatus,
  );

  /// Only what a user edit may move; the DAO stamps `updated_at` and `sync_status`. Null references are written as `Value(null)`, not left absent, so
  /// switching the type clears the old destination or category — an absent value would keep it, and the table's CHECK would refuse the row.
  TransactionsTableCompanion toPatch(TransactionEntity entity) => TransactionsTableCompanion(
    type: Value(entity.type.storageValue),
    accountId: Value(entity.accountId),
    destinationAccountId: Value(entity.destinationAccountId),
    categoryId: Value(entity.categoryId),
    amountMinor: Value(entity.amount.minorUnits),
    currencyCode: Value(entity.amount.currencyCode),
    occurredAt: Value(entity.occurredAt.millisecondsSinceEpoch),
    note: Value(entity.note),
  );
}
