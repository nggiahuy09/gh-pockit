import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/categories/domain/repositories/category_repository.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:ghpockit/features/transactions/domain/usecases/refusal_from_category.dart';

/// Saves an edited transaction — what the edit screen of W6 T4 calls on Save (W4 flex).
///
/// Owns the same rule as `CreateTransactionUseCase` (ADR-0010, rule 3), with one difference that is the reason this class is more than a copy of that one:
/// **it judges only a filing the edit makes.** The category is checked when the edit moves the transaction to another category, or changes its type while
/// it keeps one — and not otherwise.
///
/// Why not every save: deleting a category that has transactions is allowed (ADR-0010) — they keep its id and read as "Uncategorised" — so a transaction
/// under a deleted category is an ordinary state, not a race. Judging every save would make each such transaction uneditable until the user re-filed it,
/// with "no longer exists" said about a field that reads "Uncategorised". The same holds for a category whose type was flipped since (ADR-0010, _Still
/// open_): the edit did not put the transaction there. Accounts differ on purpose. The repository refuses an update whose account is gone, but an account
/// with transactions cannot be deleted at all, so that state only ever comes from a race.
///
/// Knowing what the edit changed needs the stored row, so this reads it — one lookup by id, and only when the edit carries a category. A deleted row ends
/// here as [GPNotFoundFailure], the answer the repository would give. A row whose version is not the edit's goes to the repository unjudged: the version
/// guard refuses it as a [GPConflictFailure], which invites the reload that fixes it, where judging a category against a row the edit was not based on
/// could only produce a wrong sentence.
///
/// **Failures:** everything `TransactionRepository.updateTransaction` can return, plus the three of `refusalFromCategory` before it, and a
/// [GPDatabaseFailure] when the stored row cannot be read.
class UpdateTransactionUseCase {
  const UpdateTransactionUseCase({required TransactionRepository transactionRepository, required CategoryRepository categoryRepository})
    : _transactions = transactionRepository,
      _categories = categoryRepository;

  final TransactionRepository _transactions;
  final CategoryRepository _categories;

  Future<GPResult<TransactionEntity>> call(TransactionEntity transaction) async {
    final categoryId = transaction.categoryId;
    // Uncategorised, or a transfer — which `TransactionEntity` never lets carry a category: nothing for the rule to judge.
    if (categoryId == null) return _transactions.updateTransaction(transaction);

    final TransactionEntity? stored;
    try {
      stored = await _transactions.watchTransaction(transaction.id).first;
    } on GPFailure catch (failure) {
      // `TransactionRepository` puts only a `GPFailure` on that channel; anything else is a bug and propagates, as in `refusalFromCategory`.
      return GPErr<TransactionEntity>(failure);
    }

    if (stored == null) return const GPErr<TransactionEntity>(GPNotFoundFailure());

    final filingChanged = stored.categoryId != categoryId || stored.type != transaction.type;

    if (stored.version == transaction.version && filingChanged) {
      final refused = await refusalFromCategory(_categories, categoryId: categoryId, type: transaction.type);
      if (refused != null) return GPErr<TransactionEntity>(refused);
    }

    return _transactions.updateTransaction(transaction);
  }
}
