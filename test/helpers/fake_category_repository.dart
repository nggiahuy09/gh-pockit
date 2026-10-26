import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/categories/domain/repositories/category_repository.dart';

/// Every watch is a fresh one-empty-list stream. Writes throw.
final class FakeCategoryRepository extends CategoryRepository {
  const FakeCategoryRepository();

  @override
  Stream<List<CategoryEntity>> watchCategories([CategoryType? type]) => Stream.value(const []);

  @override
  Stream<CategoryEntity?> watchCategory(String id) => throw UnimplementedError();

  @override
  Future<GPResult<CategoryEntity>> createCategory({required CategoryType type, String? colorKey, String? iconKey, required String name}) => throw UnimplementedError();

  @override
  Future<GPResult<CategoryEntity>> updateCategory(CategoryEntity category) => throw UnimplementedError();

  @override
  Future<GPResult<void>> deleteCategory(String id) => throw UnimplementedError();
}
