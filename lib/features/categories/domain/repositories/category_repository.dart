import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';

/// Writes can also fail with [GPDatabaseFailure]; streams deliver failures on their error channel as [GPFailure]. Seeding is `CategorySeeder`'s.
abstract class CategoryRepository {
  const CategoryRepository();

  /// Ordered by creation, not name: seeded rows store a key, and SQLite's `BINARY` collation misorders Vietnamese. Sort for display in Dart.
  Stream<List<CategoryEntity>> watchCategories({CategoryType? type});

  /// Emits null once the category is deleted.
  Stream<CategoryEntity?> watchCategory(String id);

  /// Always user-made: no key, not `isSystem`, a fresh v7 id. [GPValidationFailure] for a blank or too-long [name].
  Future<GPResult<CategoryEntity>> createCategory({required String name, required CategoryType type, String? iconKey, String? colorKey});

  /// Guarded on [CategoryEntity.version]: [GPConflictFailure] when stale, [GPNotFoundFailure] when the row is gone. Returns the entity restamped.
  Future<GPResult<CategoryEntity>> updateCategory(CategoryEntity category);

  /// Soft delete, allowed for a system category too; re-seeding does not bring it back. Its transactions keep their `category_id` and read as
  /// "Uncategorised" (ADR-0010). [GPNotFoundFailure] when there is no live row.
  Future<GPResult<void>> deleteCategory(String id);
}
