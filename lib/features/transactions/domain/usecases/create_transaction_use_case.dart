import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/categories/domain/repositories/category_repository.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:ghpockit/features/transactions/domain/usecases/refusal_from_category.dart';

/// ADR-0010 rule 3, checked before the repository: a category that is not live is a [GPNotFoundFailure], one of the other kind a [GPValidationFailure].
class CreateTransactionUseCase {
  const CreateTransactionUseCase({required TransactionRepository transactionRepository, required CategoryRepository categoryRepository})
    : _transactions = transactionRepository,
      _categories = categoryRepository;

  final TransactionRepository _transactions;
  final CategoryRepository _categories;

  Future<GPResult<TransactionEntity>> call({
    required TransactionType type,
    required String accountId,
    required Money amount,
    required DateTime occurredAt,
    String? destinationAccountId,
    String? categoryId,
    String? note,
  }) async {
    if (categoryId != null) {
      final refused = await refusalFromCategory(_categories, categoryId: categoryId, type: type);
      if (refused != null) return GPErr<TransactionEntity>(refused);
    }

    return _transactions.createTransaction(
      type: type,
      accountId: accountId,
      amount: amount,
      occurredAt: occurredAt,
      destinationAccountId: destinationAccountId,
      categoryId: categoryId,
      note: note,
    );
  }
}
