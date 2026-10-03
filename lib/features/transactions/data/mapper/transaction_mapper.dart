import 'package:drift/drift.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

/// Why a stored `transactions` row could not be read — the three checks `AccountMapperReason` names, for the same reason: the user reads one sentence, the
/// log reads which check refused the row. A reason names a check, never a value, so it is exactly what golden rule 9 lets a log line carry.
enum TransactionMapperReason {
  /// `type` held a string no [TransactionType] knows — a `refund` from a newer build, say, or a corrupted row. The column has no vocabulary CHECK by design
  /// (ADR-0009), so this is where an unknown value is caught.
  unknownType,

  /// `currency_code` was three characters but not three A–Z letters. The length is the table's CHECK; the alphabet is `Money`'s.
  malformedCurrencyCode,

  /// The row parsed but broke a rule of [TransactionEntity] — a note longer than this build accepts, written by one with a larger limit. The table's
  /// CHECKs make the other rules unbreakable in storage.
  brokenDomainRule,
}

/// The outcome of reading one `transactions` row. Sealed for the reason `AccountMapping` gives: adding a reason without deciding what happens to it does
/// not compile.
sealed class TransactionMapping {
  const TransactionMapping();
}

/// The row was read.
final class MappedTransaction extends TransactionMapping {
  const MappedTransaction(this.transaction);

  final TransactionEntity transaction;
}

/// The row was not read, and [reason] says which check refused it.
final class UnmappableTransactionRow extends TransactionMapping {
  const UnmappableTransactionRow(this.reason);

  final TransactionMapperReason reason;

  /// Always [GPDatabaseFailure], whatever the reason — the flattening `UnmappableAccountRow.failure` explains. On the list it is never shown: the row is
  /// counted instead (ADR-0011). It reaches a screen only through `watchTransaction`, where one row has no partial answer.
  GPFailure get failure => const GPDatabaseFailure();
}

/// The one place that knows how a `transactions` row becomes a [TransactionEntity] and back (W4 T6).
///
/// The translations `AccountMapper` makes, plus what this table adds: `type` ↔ [TransactionType] through `storageValue`, `amount_minor` +
/// `currency_code` ↔ one [Money], epoch millis ↔ UTC `DateTime` — `occurred_at` included, an instant like every other timestamp (ADR-0009). And two
/// things appear or vanish on the way: `owner_id`, which the entity does not carry and the repository supplies; and `sync_status`, which the entity does
/// not carry either (ADR-0009) and the DAO stamps on every write.
///
/// Stateless and `const`, held by the repository as a default argument, like `AccountMapper`.
class TransactionMapper {
  const TransactionMapper();

  /// Parses a row into a [MappedTransaction], or an [UnmappableTransactionRow] naming the check that refused it.
  ///
  /// Tombstones are not filtered here: every read in `TransactionDao` except `findById` already does it, and `findById` wants them.
  ///
  /// The row goes through [TransactionEntity.create] like any other input, so a row written around the entity — by a newer build, or by hand while
  /// debugging — is judged by the same rules. Its normalising can change nothing the table's CHECKs allow: a stored transfer has no category and a stored
  /// expense has no destination already.
  TransactionMapping toEntity(TransactionRow row) {
    final type = TransactionType.fromStorage(row.type);
    if (type == null) return const UnmappableTransactionRow(TransactionMapperReason.unknownType);

    // `Money.fromStorage`, not the throwing `Money(...)`: a malformed code handed back by SQLite is data, not a bug in this program (ADR-0006) — the same
    // boundary `AccountMapper` draws.
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
      // The entity's own validation code is dropped, not forwarded — see [UnmappableTransactionRow.failure].
      GPErr<TransactionEntity>() => const UnmappableTransactionRow(TransactionMapperReason.brokenDomainRule),
    };
  }

  /// The companion for a fresh insert — every column stated, nothing defaulted, through `.insert` so a column added to the table without a value here is
  /// a compile error (the reasoning of `AccountMapper.toInsert`).
  ///
  /// `syncStatus` is [TransactionDao.pendingSyncStatus] because `.insert` requires a value; the DAO stamps the same one over it regardless. `deleted_at` is
  /// left out, so a new row is live.
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

  /// The patch for an update: exactly the columns a user edit may move.
  ///
  /// **Not** `id`, `owner_id` or `created_at` (identity and birth), `version` (the server's, §7), `deleted_at` (deleting is its own operation), and not
  /// `updated_at` or `sync_status` — the DAO stamps both on every write, from the caller's instant.
  ///
  /// The nullable references are written even when null — `Value(null)`, not absent — because switching a transfer back to an expense has to *clear* its
  /// destination, and switching an expense to a transfer has to clear its category. An absent value would leave the old one in place and the table's
  /// CHECK would refuse the row.
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
