import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/categories/domain/repositories/category_repository.dart';

/// Every watch is a fresh one-empty-list stream. Writes throw.
class FakeCategoryRepository implements CategoryRepository {
  @override
  Stream<List<CategoryEntity>> watchCategories({CategoryType? type}) => Stream<List<CategoryEntity>>.value(const <CategoryEntity>[]);

  @override
  Stream<CategoryEntity?> watchCategory(String id) => throw UnimplementedError();

  @override
  Future<GPResult<CategoryEntity>> createCategory({required String name, required CategoryType type, String? iconKey, String? colorKey}) => throw UnimplementedError();

  @override
  Future<GPResult<CategoryEntity>> updateCategory(CategoryEntity category) => throw UnimplementedError();

  @override
  Future<GPResult<void>> deleteCategory(String id) => throw UnimplementedError();
}
