import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_balance.dart';
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

  /// Not guarded by version, and no account rule: a transaction on an account already gone must stay deletable.
  Future<GPResult<void>> deleteTransaction(String id);

  /// Undoes [deleteTransaction] (ADR-0017). [GPNotFoundFailure] when [id] is no deleted transaction, or when an account it names is no longer live: a row
  /// coming back holds the account rules a new one does. Not guarded by version.
  Future<GPResult<void>> restoreTransaction(String id);

  /// Either side of a transfer counts; deleted transactions do not.
  Future<GPResult<bool>> hasLiveTransactions(String accountId);

  /// Every live, unarchived account with its balance (ADR-0009), in `AccountRepository.watchAccounts`' order. One query, so the accounts and their
  /// balances are one snapshot (ADR-0019). Re-emits on any write to either table. A deleted account's transfers still count on the account at the
  /// other end (ADR-0010). An account row that will not map fails the list, as `watchAccounts` does; the error channel carries a [GPDatabaseFailure].
  Stream<List<AccountBalance>> watchAccountBalances();
}
