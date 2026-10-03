import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/categories/domain/repositories/category_repository.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:ghpockit/features/transactions/domain/usecases/refusal_from_category.dart';

/// Records a new transaction — what the form of W6 T2 calls on Save (W4 flex).
///
/// **It exists for one rule** (ADR-0010, rule 3): an expense is filed under an expense category and an income under an income one, and the category is
/// still there. That rule is about what a category *means* — a row filed under the wrong kind is still readable and its balance still computes — so it
/// belongs in the domain rather than in `TransactionRepositoryImpl`, and it is the whole of what this class adds. Everything else — the entity's own rules,
/// the account rules checked inside the write, the id and the clock — is the repository's, and the failures it returns come back unchanged.
///
/// Takes the repository's fields, not an entity, for the reason `TransactionRepository.createTransaction` gives: the id and the timestamps come from behind
/// that interface.
///
/// **Failures:** everything `TransactionRepository.createTransaction` can return, plus, before the repository sees the input —
///
/// - [GPNotFoundFailure] — the category is soft-deleted, or not there at all. The second would otherwise reach the foreign key and come back as a
///   [GPDatabaseFailure], a sentence about local storage for what is a stale picker;
/// - [GPValidationCode.transactionCategoryTypeMismatch] — the category is of the other kind;
/// - [GPDatabaseFailure] — the category could not be read.
///
/// Because the category is judged first, its failure is the one returned when the input breaks an entity rule as well — the price of checking it outside
/// the repository, and a small one: the picker of W6 only offers live categories of the right kind, so this answer is for a race, not for typing.
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
    // No category, no rule: "uncategorised" is a filing of its own. A transfer's category is let through unjudged — the entity drops it.
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
