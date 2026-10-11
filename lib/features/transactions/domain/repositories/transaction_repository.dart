import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_list_snapshot.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

/// Writes fail with [GPNotFoundFailure] when an account they name is not live (archived counts as live) and [GPValidationFailure] when the amount is not
/// in its currency. The category rule is the use cases', not this interface's (ADR-0010).
abstract class TransactionRepository {
  const TransactionRepository();

  /// Still returns rows whose account or category is soft-deleted: sync can produce them, so readers tolerate them (ADR-0010). Unmappable rows are
  /// counted, not errors; the error channel only ever carries a [GPDatabaseFailure] (ADR-0011).
  Stream<TransactionListSnapshot> watchTransactions(TransactionQuery query);

  /// Emits null once the transaction is deleted. An unmappable row is a [GPDatabaseFailure] on the error channel.
  Stream<TransactionEntity?> watchTransaction(String id);

  Future<GPResult<TransactionEntity>> createTransaction({
    required TransactionType type,
    required String accountId,
    required Money amount,
    required DateTime occurredAt,
    String? destinationAccountId,
    String? categoryId,
    String? note,
  });

  /// Guarded on [TransactionEntity.version], so a stale one is a [GPConflictFailure]. Returns the entity with a fresh `updatedAt`.
  Future<GPResult<TransactionEntity>> updateTransaction(TransactionEntity transaction);

  /// Not guarded by version. No use case wraps it: deleting owns no rule (ADR-0010).
  Future<GPResult<void>> deleteTransaction(String id);

  /// Either side of a transfer counts; deleted transactions do not.
  Future<GPResult<bool>> hasLiveTransactions(String accountId);
}
