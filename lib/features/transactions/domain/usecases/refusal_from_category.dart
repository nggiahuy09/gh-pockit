import '../../../../core/error/failure.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../entities/transaction_type.dart';

/// ADR-0010 rule 3: null when [type] may be filed under [categoryId]. Runs outside the write's transaction, a race the ADR accepts.
Future<GPFailure?> refusalFromCategory(CategoryRepository repository, {required TransactionType type, required String categoryId}) async {
  final expected = type.categoryType;
  if (expected == null) return null;

  final CategoryEntity? category;
  try {
    category = await repository.watchCategory(categoryId).first;
  } on GPFailure catch (failure) {
    return failure;
  }

  if (category == null) return const GPNotFoundFailure();
  if (category.type != expected) return const GPValidationFailure(GPValidationCode.transactionCategoryTypeMismatch);

  return null;
}
