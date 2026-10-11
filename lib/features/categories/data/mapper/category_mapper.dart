import 'package:drift/drift.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';

/// Goes to the log, so a reason names a check and never a value from the row (golden rule 9).
enum CategoryMapperReason {
  /// A newer build's type, or a corrupt row.
  unknownType,

  /// `CategoryEntity.create` refused the row.
  brokenDomainRule,
}

/// Not a `GPResult`: the user-facing failure is always the same, and the log needs the [CategoryMapperReason].
sealed class CategoryMapping {
  const CategoryMapping();
}

final class MappedCategory extends CategoryMapping {
  const MappedCategory(this.category);

  final CategoryEntity category;
}

final class UnmappableCategoryRow extends CategoryMapping {
  const UnmappableCategoryRow(this.reason);

  final CategoryMapperReason reason;

  GPFailure get failure => const GPDatabaseFailure();
}

class CategoryMapper {
  const CategoryMapper();

  /// Maps a tombstone like a live row; the DAO's reads are what filter them.
  CategoryMapping toEntity(CategoryRow row) {
    final type = CategoryType.fromStorage(row.type);
    if (type == null) return const UnmappableCategoryRow(CategoryMapperReason.unknownType);

    final entity = CategoryEntity.create(
      id: row.id,
      nameKey: row.nameKey,
      name: row.name,
      type: type,
      iconKey: row.iconKey,
      colorKey: row.colorKey,
      isSystem: row.isSystem,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
      version: row.version,
    );

    return switch (entity) {
      GPOk<CategoryEntity>(:final value) => MappedCategory(value),
      GPErr<CategoryEntity>() => const UnmappableCategoryRow(CategoryMapperReason.brokenDomainRule),
    };
  }

  /// `.insert` rather than the unnamed constructor, so a new required column is a compile error here, not a missing value.
  CategoriesTableCompanion toInsert(CategoryEntity entity, {required String ownerId}) => CategoriesTableCompanion.insert(
    id: entity.id,
    ownerId: ownerId,
    nameKey: Value(entity.nameKey),
    name: Value(entity.name),
    type: entity.type.storageValue,
    iconKey: Value(entity.iconKey),
    colorKey: Value(entity.colorKey),
    isSystem: entity.isSystem,
    createdAt: entity.createdAt.millisecondsSinceEpoch,
    updatedAt: entity.updatedAt.millisecondsSinceEpoch,
    version: entity.version,
  );

  /// Only what an edit may change: `name_key` and `is_system` are provenance, `version` is the server's, `updated_at` is stamped by the DAO.
  /// A null name writes NULL, the "use the default name again" edit.
  CategoriesTableCompanion toPatch(CategoryEntity entity) => CategoriesTableCompanion(
    name: Value(entity.name),
    type: Value(entity.type.storageValue),
    iconKey: Value(entity.iconKey),
    colorKey: Value(entity.colorKey),
  );
}
