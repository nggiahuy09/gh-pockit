import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:meta/meta.dart';

/// Money moving: spent from an account, received into one, or transferred between two (blueprint §17).
///
/// The row/entity split is the one `AccountEntity` documents — no `ownerId`, no `deletedAt`, `DateTime` instead of epoch millis, `version` visible because
/// §7 makes a conflict a user-facing outcome. What this table adds:
///
/// | Row has | Entity has | Why they differ |
/// | --- | --- | --- |
/// | `amount_minor` + `currency_code` | one [Money] | Same reason as `AccountEntity.initialBalance`: an amount travelling without its currency is how dong end up rendered as dollars. |
/// | `sync_status` | — | Sync bookkeeping. Every local write sets it to `pending` in the DAO, and nothing in the domain branches on it until the badge of W12 flex (ADR-0009). |
/// | `int occurred_at` | `DateTime occurredAt` | An instant, in UTC. Which *day* it falls on depends on the zone it is shown in, which is presentation's to decide (ADR-0009). |
///
/// **What this type can check, and what it cannot.** Every rule that is about the transaction alone is enforced here, by [create]: the amount is
/// positive, a transfer has a destination that is not its own source, a note fits. Three rules need another entity's row and so cannot live here —
/// that the account is still there, that the amount's currency is the account's, and that an expense is filed under an expense category. ADR-0010 puts the
/// first two in the repository, inside the write transaction, and the third in the use cases.
///
/// Immutable, like every entity here: an edit produces a new instance through [update].
@immutable
final class TransactionEntity {
  const TransactionEntity._({
    required this.id,
    required this.type,
    required this.accountId,
    required this.destinationAccountId,
    required this.categoryId,
    required this.amount,
    required this.occurredAt,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  /// Longest note accepted, in UTF-16 code units — code units rather than characters for the reason `AccountEntity.nameMaxLength` gives.
  ///
  /// A limit exists because `transactions.note` is unbounded `TEXT` that syncs, and of every text column it is the one most likely to receive a paste. 500
  /// is a few sentences about a purchase — "Ăn trưa với team, chia 4 người, Minh trả trước" is 46 — and small enough that fifty thousand of them stay a sane
  /// table. A receipt's full text belongs to the receipt (W29+), not here.
  static const int noteMaxLength = 500;

  final String id;

  final TransactionType type;

  /// The account the money leaves — for an expense and for a transfer — or arrives in, for an income.
  final String accountId;

  /// Where a transfer's money arrives. Always set on a transfer and always null on anything else — [create] makes that true by construction, and the
  /// table's CHECK makes it true of every row.
  final String? destinationAccountId;

  /// What the transaction is filed under, or null for "uncategorised". Always null on a transfer, which is spending in no category.
  ///
  /// Whether an expense sits under an expense category is **not** checked here: it needs the category's row (ADR-0010).
  final String? categoryId;

  /// Always positive — the [type] carries the direction (ADR-0009). For a transfer, the currency is both accounts' currency; that the two agree is the
  /// repository's check, not this type's.
  final Money amount;

  /// When the money moved, as an instant in UTC. [create] normalises.
  final DateTime occurredAt;

  /// Free text the user typed, trimmed, or null. `''` and "no note" are one state: [create] turns an empty note into null.
  final String? note;

  /// UTC, always. [create] normalises.
  final DateTime createdAt;

  /// UTC. Half the pull cursor at W14 T2, stamped by the repository from `GPClock`.
  final DateTime updatedAt;

  /// Optimistic-concurrency token (§7). The server's number; the client sends it back as `baseVersion` and never increments it.
  final int version;

  /// The only way to build a [TransactionEntity], and the only place its own rules live.
  ///
  /// Returns a [GPResult] for the ADR-0006 reason: every failure below is something a correct user produces by ordinary use of a form — an amount of 0, a
  /// transfer with no destination picked yet. Used by the mapper too, so a row that went bad is caught at the boundary; the table's CHECKs make most such
  /// rows impossible, and ADR-0011 decides what the list does with the rest.
  ///
  /// **The type decides which optional reference survives.** A transfer's [categoryId] and a non-transfer's [destinationAccountId] are dropped rather than
  /// refused. Neither can be typed by a user; both are what a form leaves behind when the type is switched after the other field was filled in. Refusing
  /// would make every such form clear the field by hand, and a form that forgets would be told "invalid" about a field that is no longer on screen.
  /// Dropping them is also what lets [update] switch a type in one call.
  ///
  /// Checked in the order a form lays them out — amount, destination, note — so a form that shows one message at a time shows the topmost one.
  static GPResult<TransactionEntity> create({
    required String id,
    required TransactionType type,
    required String accountId,
    required Money amount,
    required DateTime occurredAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? destinationAccountId,
    String? categoryId,
    String? note,
    int version = 1,
  }) {
    if (amount.minorUnits <= 0) return const GPErr<TransactionEntity>(GPValidationFailure(GPValidationCode.transactionAmountNotPositive));

    final isTransfer = type == TransactionType.transfer;
    final destination = isTransfer ? destinationAccountId : null;
    final category = isTransfer ? null : categoryId;

    if (isTransfer && destination == null) return const GPErr<TransactionEntity>(GPValidationFailure(GPValidationCode.transactionDestinationMissing));

    if (isTransfer && destination == accountId) return const GPErr<TransactionEntity>(GPValidationFailure(GPValidationCode.transactionDestinationSameAsSource));

    // Trim, then an empty result becomes null, and only then is the length checked — the same order as `CategoryEntity.name`, and for the same reason: a
    // note of spaces is no note, and a limit measured before trimming would reject a paste for characters nobody can see.
    final trimmedNote = note?.trim();
    final normalizedNote = (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote;

    if (normalizedNote != null && normalizedNote.length > noteMaxLength) return const GPErr<TransactionEntity>(GPValidationFailure(GPValidationCode.transactionNoteTooLong));

    return GPOk<TransactionEntity>(
      TransactionEntity._(
        id: id,
        type: type,
        accountId: accountId,
        destinationAccountId: destination,
        categoryId: category,
        amount: amount,
        occurredAt: occurredAt.toUtc(),
        note: normalizedNote,
        createdAt: createdAt.toUtc(),
        updatedAt: updatedAt.toUtc(),
        version: version,
      ),
    );
  }

  /// A copy with some fields changed, re-validated — the call a form makes on Save.
  ///
  /// [id], [createdAt] and [updatedAt] are absent for the reasons `AccountEntity.update` spells out: identity and birth date do not change, and "now"
  /// belongs to the repository's clock. Restamping is [stampedAt].
  ///
  /// **Switching [type] is one call**, because [create] drops whichever reference the new type cannot carry: `update(type: TransactionType.transfer,
  /// destinationAccountId: 'acc-2')` on an expense loses its category, and `update(type: TransactionType.expense)` on a transfer loses its destination. A
  /// switch to transfer without a destination fails as `transactionDestinationMissing`, exactly as a new one would.
  ///
  /// **[clearCategory] exists because `null` already means "leave it alone"** — the same problem `CategoryEntity.update` solves with `clearName`. A note
  /// needs no flag: a form passes the field's text as it is, and `''` is normalised to "no note" by [create].
  GPResult<TransactionEntity> update({
    TransactionType? type,
    String? accountId,
    String? destinationAccountId,
    String? categoryId,
    Money? amount,
    DateTime? occurredAt,
    String? note,
    int? version,
    bool clearCategory = false,
  }) => create(
    id: id,
    type: type ?? this.type,
    accountId: accountId ?? this.accountId,
    destinationAccountId: destinationAccountId ?? this.destinationAccountId,
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    amount: amount ?? this.amount,
    occurredAt: occurredAt ?? this.occurredAt,
    note: note ?? this.note,
    createdAt: createdAt,
    updatedAt: updatedAt,
    version: version ?? this.version,
  );

  /// The same transaction with a new [updatedAt]. Cannot fail, because nothing validated changes — so not a [GPResult], for the reason
  /// `AccountEntity.stampedAt` gives.
  TransactionEntity stampedAt(DateTime updatedAt) => TransactionEntity._(
    id: id,
    type: type,
    accountId: accountId,
    destinationAccountId: destinationAccountId,
    categoryId: categoryId,
    amount: amount,
    occurredAt: occurredAt,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt.toUtc(),
    version: version,
  );

  /// Value equality over every field. At transaction scale this matters more than anywhere else: a Drift stream re-emits a freshly mapped page after every
  /// write to the table, and without it every write would rebuild every row on screen.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionEntity &&
          other.id == id &&
          other.type == type &&
          other.accountId == accountId &&
          other.destinationAccountId == destinationAccountId &&
          other.categoryId == categoryId &&
          other.amount == amount &&
          other.occurredAt == occurredAt &&
          other.note == note &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt &&
          other.version == version;

  @override
  int get hashCode => Object.hash(id, type, accountId, destinationAccountId, categoryId, amount, occurredAt, note, createdAt, updatedAt, version);

  /// **Carries no amount and no note, deliberately** — golden rule 9 names both. This entity is interpolated into repository and sync logs, and
  /// `redactSensitiveFields` only sees maps, so the safe string has to be the default one.
  @override
  String toString() => 'TransactionEntity(id: $id, type: ${type.name}, version: $version)';
}
