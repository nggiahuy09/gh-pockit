import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/category_entity.dart';
import '../entities/category_type.dart';

abstract class CategoryRepository {
  const CategoryRepository();

  /// Ordered by creation, not name: SQLite's `BINARY` collation misorders Vietnamese. Sort for display in Dart.
  Stream<List<CategoryEntity>> watchCategories([CategoryType? type]);

  /// Emits null once the category is deleted.
  Stream<CategoryEntity?> watchCategory(String id);

  /// Always user-made: no key, not `isSystem`.
  Future<GPResult<CategoryEntity>> createCategory({required CategoryType type, String? colorKey, String? iconKey, required String name});

  /// [GPConflictFailure] when stale, [GPNotFoundFailure] when the row is gone.
  Future<GPResult<CategoryEntity>> updateCategory(CategoryEntity category);

  /// Also for a system category; re-seeding does not bring it back. Its transactions read as "Uncategorised" (ADR-0010).
  Future<GPResult<void>> deleteCategory(String id);
}
