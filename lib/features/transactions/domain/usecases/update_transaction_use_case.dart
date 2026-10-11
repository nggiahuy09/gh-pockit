import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/categories/domain/repositories/category_repository.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:ghpockit/features/transactions/domain/usecases/refusal_from_category.dart';

/// ADR-0010 rule 3, judged only when the edit changes the filing (a new category, or a new type keeping one): a transaction under a category deleted or
/// flipped since must stay editable.
class UpdateTransactionUseCase {
  const UpdateTransactionUseCase({required TransactionRepository transactionRepository, required CategoryRepository categoryRepository})
    : _transactions = transactionRepository,
      _categories = categoryRepository;

  final TransactionRepository _transactions;
  final CategoryRepository _categories;

  Future<GPResult<TransactionEntity>> call(TransactionEntity transaction) async {
    final categoryId = transaction.categoryId;
    if (categoryId == null) return _transactions.updateTransaction(transaction);

    final TransactionEntity? stored;
    try {
      stored = await _transactions.watchTransaction(transaction.id).first;
    } on GPFailure catch (failure) {
      // Anything that is not a `GPFailure` is a bug: let it propagate.
      return GPErr<TransactionEntity>(failure);
    }

    if (stored == null) return const GPErr<TransactionEntity>(GPNotFoundFailure());

    final filingChanged = stored.categoryId != categoryId || stored.type != transaction.type;

    // A stale edit skips the rule: the version guard reports it as a conflict, where judging it against a row it was not based on would mislead.
    if (stored.version == transaction.version && filingChanged) {
      final refused = await refusalFromCategory(_categories, categoryId: categoryId, type: transaction.type);
      if (refused != null) return GPErr<TransactionEntity>(refused);
    }

    return _transactions.updateTransaction(transaction);
  }
}
