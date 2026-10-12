import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/categories/domain/repositories/category_repository.dart';

/// Forwards on purpose (ADR-0013).
class WatchCategoriesUseCase {
  const WatchCategoriesUseCase({required CategoryRepository categoryRepository}) : _categories = categoryRepository;

  final CategoryRepository _categories;

  Stream<List<CategoryEntity>> call({CategoryType? type}) => _categories.watchCategories(type: type);
}
