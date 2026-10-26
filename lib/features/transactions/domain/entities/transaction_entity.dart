import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/money/money.dart';
import 'transaction_type.dart';

/// Validates only its own fields. Rules that need the account or category row live in the repository and the use cases (ADR-0010).
@immutable
final class TransactionEntity with Equatable {
  const TransactionEntity._({
    required this.amount,
    required this.type,
    required this.createdAt,
    required this.occurredAt,
    required this.updatedAt,
    required this.accountId,
    required this.categoryId,
    required this.destinationAccountId,
    required this.id,
    required this.note,
    required this.version,
  });

  /// A transfer's category and a non-transfer's destination are dropped, not refused: a form leaves them behind when the type is switched. Checks run
  /// in form order, so the first failure is the topmost field.
  static GPResult<TransactionEntity> create({
    required Money amount,
    required TransactionType type,
    required DateTime createdAt,
    required DateTime occurredAt,
    required DateTime updatedAt,
    required String accountId,
    String? categoryId,
    String? destinationAccountId,
    required String id,
    String? note,
    int version = 1,
  }) {
    if (!amount.isPositive) return const GPErr(GPValidationFailure(GPValidationCode.transactionAmountNotPositive));

    final destination = type.isTransfer ? destinationAccountId : null;
    if (type.isTransfer && destination == null) return const GPErr(GPValidationFailure(GPValidationCode.transactionDestinationMissing));
    if (type.isTransfer && destination == accountId) return const GPErr(GPValidationFailure(GPValidationCode.transactionDestinationSameAsSource));

    final trimmedNote = note?.trim();
    final normalizedNote = (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote;
    if (normalizedNote != null && normalizedNote.length > noteMaxLength) return const GPErr(GPValidationFailure(GPValidationCode.transactionNoteTooLong));

    return GPOk(
      TransactionEntity._(
        amount: amount,
        type: type,
        createdAt: createdAt.toUtc(),
        occurredAt: occurredAt.toUtc(),
        updatedAt: updatedAt.toUtc(),
        accountId: accountId,
        categoryId: type.isTransfer ? null : categoryId,
        destinationAccountId: destination,
        id: id,
        note: normalizedNote,
        version: version,
      ),
    );
  }

  /// Always positive: [type] gives the direction (ADR-0009).
  final Money amount;

  final TransactionType type;
  final DateTime createdAt;
  final DateTime occurredAt;
  final DateTime updatedAt;

  /// Source of an expense or a transfer; destination of an income.
  final String accountId;

  final String? categoryId;
  final String? destinationAccountId;
  final String id;
  final String? note;

  /// The server's optimistic-concurrency token: the client never increments it.
  final int version;

  static const noteMaxLength = 500;

  @override
  List<Object?> get props => [amount, type, createdAt, occurredAt, updatedAt, accountId, categoryId, destinationAccountId, id, note, version];

  /// Null keeps a field: clear the category and the destination with the flags, the note by passing `''`.
  GPResult<TransactionEntity> update({
    Money? amount,
    TransactionType? type,
    DateTime? occurredAt,
    String? accountId,
    String? categoryId,
    String? destinationAccountId,
    String? note,
    int? version,
    bool clearCategory = false,
    bool clearDestination = false,
  }) => create(
    amount: amount ?? this.amount,
    type: type ?? this.type,
    createdAt: createdAt,
    occurredAt: occurredAt ?? this.occurredAt,
    updatedAt: updatedAt,
    accountId: accountId ?? this.accountId,
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    destinationAccountId: clearDestination ? null : (destinationAccountId ?? this.destinationAccountId),
    id: id,
    note: note ?? this.note,
    version: version ?? this.version,
  );

  TransactionEntity withUpdatedAt(DateTime updatedAt) => TransactionEntity._(
    amount: amount,
    type: type,
    createdAt: createdAt,
    occurredAt: occurredAt,
    updatedAt: updatedAt.toUtc(),
    accountId: accountId,
    categoryId: categoryId,
    destinationAccountId: destinationAccountId,
    id: id,
    note: note,
    version: version,
  );

  /// No amount or note: entities end up in logs (golden rule 9).
  @override
  String toString() => 'TransactionEntity(id: $id, type: ${type.name}, version: $version)';
}
