import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/money/money.dart';
import '../../../accounts/domain/entities/account_balance.dart';
import '../entities/transaction_entity.dart';
import '../entities/transaction_list_snapshot.dart';
import '../entities/transaction_query.dart';
import '../entities/transaction_type.dart';

/// Writes fail with [GPNotFoundFailure] when an account they name is not live, and [GPValidationFailure] when the amount is not in its currency. The
/// category rule is the use cases' (ADR-0010).
abstract class TransactionRepository {
  const TransactionRepository();

  /// Keeps rows whose account or category is soft-deleted: sync can produce them (ADR-0010). Unmappable rows are counted, not errors (ADR-0011).
  Stream<TransactionListSnapshot> watchTransactions(TransactionQuery query);

  /// Emits null once the transaction is deleted.
  Stream<TransactionEntity?> watchTransaction(String id);

  Future<GPResult<TransactionEntity>> createTransaction({
    required Money amount,
    required TransactionType type,
    required DateTime occurredAt,
    required String accountId,
    String? categoryId,
    String? destinationAccountId,
    String? note,
  });

  /// [GPConflictFailure] when stale.
  Future<GPResult<TransactionEntity>> updateTransaction(TransactionEntity transaction);

  /// No version guard and no account rule: a transaction on an account already gone must stay deletable.
  Future<GPResult<void>> deleteTransaction(String id);

  /// Undoes [deleteTransaction] (ADR-0017). [GPNotFoundFailure] when an account it names is no longer live.
  Future<GPResult<void>> restoreTransaction(String id);

  /// Either side of a transfer counts.
  Future<GPResult<bool>> hasLiveTransactions(String accountId);

  /// Every live, unarchived account with its balance, in one query so both are one snapshot (ADR-0019).
  Stream<List<AccountBalance>> watchAccountBalances();
}
