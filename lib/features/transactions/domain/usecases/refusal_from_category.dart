import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/categories/domain/repositories/category_repository.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

/// Rule 3 of ADR-0010, the one rule `CreateTransactionUseCase` and `UpdateTransactionUseCase` exist to own: a transaction of [type] may be filed under
/// [categoryId] only while that category is live and of the matching kind. Null when it may; otherwise the failure that says why not —
///
/// - [GPNotFoundFailure] — no live category with that id: soft-deleted, never there, or another owner's;
/// - [GPValidationCode.transactionCategoryTypeMismatch] — an expense under an income category, or the reverse;
/// - whatever the category read put on its error channel, which `CategoryRepository` promises is a [GPFailure] — a [GPDatabaseFailure] in practice.
///
/// A function rather than a class, and shared rather than written twice: both use cases ask the same question with the same three answers, and a type
/// around one method would be a name with nothing to hold.
///
/// **The category is read with `.first` of the live read**, not through a one-shot method `CategoryRepository` would have to grow: the check happens once,
/// at the write, and the stream already answers with exactly the three outcomes above. Outside the write's transaction, as ADR-0010 accepts — a sync can
/// still slip a deletion in between, which is one more reason every reader tolerates a deleted category.
Future<GPFailure?> refusalFromCategory(CategoryRepository categories, {required String categoryId, required TransactionType type}) async {
  final expected = switch (type) {
    TransactionType.expense => CategoryType.expense,
    TransactionType.income => CategoryType.income,
    // `TransactionEntity.create` drops a transfer's category rather than refusing it — it is what a form leaves behind when the type is switched — so there
    // is nothing to judge. A new transaction type fails to compile here until someone decides which categories it may carry.
    TransactionType.transfer => null,
  };
  if (expected == null) return null;

  final CategoryEntity? category;
  try {
    category = await categories.watchCategory(categoryId).first;
  } on GPFailure catch (failure) {
    // Only a `GPFailure` is an outcome. Anything else on that channel is a bug, and it propagates to the crash reporter rather than into a sentence.
    return failure;
  }

  if (category == null) return const GPNotFoundFailure();
  if (category.type != expected) return const GPValidationFailure(GPValidationCode.transactionCategoryTypeMismatch);

  return null;
}
