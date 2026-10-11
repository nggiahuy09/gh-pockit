import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:meta/meta.dart';

/// Validates only its own fields. Rules that need the account or category row live in the repository and the use cases (ADR-0010).
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

  /// In UTF-16 code units, not characters.
  static const int noteMaxLength = 500;

  final String id;
  final TransactionType type;

  /// Source of an expense or a transfer; destination of an income.
  final String accountId;

  /// Set on a transfer, null on anything else.
  final String? destinationAccountId;

  /// Null for uncategorised, and always null on a transfer.
  final String? categoryId;

  /// Always positive: [type] gives the direction (ADR-0009).
  final Money amount;

  final DateTime occurredAt;

  /// Trimmed, and null rather than empty.
  final String? note;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// The server's optimistic-concurrency token (§7); the client never increments it.
  final int version;

  /// A transfer's [categoryId] and a non-transfer's [destinationAccountId] are dropped, not refused: they are what a form leaves behind when the type is
  /// switched. Checks run in form order (amount, destination, note), so the first failure is the topmost field.
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

  /// A null argument keeps the field. The category is cleared with [clearCategory], the note by passing `''`.
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

  /// No amount or note: entities end up in logs (golden rule 9).
  @override
  String toString() => 'TransactionEntity(id: $id, type: ${type.name}, version: $version)';
}
