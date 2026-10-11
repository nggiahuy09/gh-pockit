import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/categories/domain/repositories/category_repository.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

/// ADR-0010 rule 3. Null when [type] may be filed under [categoryId]; otherwise [GPNotFoundFailure] (no live category), the type-mismatch
/// [GPValidationFailure], or the category read's own [GPFailure]. Runs outside the write's transaction, a race ADR-0010 accepts.
Future<GPFailure?> refusalFromCategory(CategoryRepository categories, {required String categoryId, required TransactionType type}) async {
  final expected = switch (type) {
    TransactionType.expense => CategoryType.expense,
    TransactionType.income => CategoryType.income,
    // The entity drops a transfer's category, so there is nothing to judge.
    TransactionType.transfer => null,
  };
  if (expected == null) return null;

  final CategoryEntity? category;
  try {
    category = await categories.watchCategory(categoryId).first;
  } on GPFailure catch (failure) {
    // Anything that is not a `GPFailure` is a bug: let it reach the crash reporter.
    return failure;
  }

  if (category == null) return const GPNotFoundFailure();
  if (category.type != expected) return const GPValidationFailure(GPValidationCode.transactionCategoryTypeMismatch);

  return null;
}
