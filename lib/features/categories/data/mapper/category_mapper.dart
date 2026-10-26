import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/category_type.dart';

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

extension CategoryRowMapper on CategoryRow {
  /// Maps a tombstone like a live row: the DAO's reads filter them.
  CategoryMapping toDomain() {
    final categoryType = CategoryType.fromStorage(type);
    if (categoryType == null) return const UnmappableCategoryRow(CategoryMapperReason.unknownType);

    final entity = CategoryEntity.create(
      type: categoryType,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt, isUtc: true),
      colorKey: colorKey,
      iconKey: iconKey,
      id: id,
      name: name,
      nameKey: nameKey,
      version: version,
      isSystem: isSystem,
    );

    return switch (entity) {
      GPOk(:final value) => MappedCategory(value),
      GPErr() => const UnmappableCategoryRow(CategoryMapperReason.brokenDomainRule),
    };
  }
}

extension CategoryEntityMapper on CategoryEntity {
  /// `.insert`, so a new non-null column is a compile error here until it is set.
  CategoriesTableCompanion toInsert(String ownerId) => CategoriesTableCompanion.insert(
    id: id,
    ownerId: ownerId,
    nameKey: Value(nameKey),
    name: Value(name),
    type: type.storageValue,
    iconKey: Value(iconKey),
    colorKey: Value(colorKey),
    isSystem: isSystem,
    createdAt: createdAt.millisecondsSinceEpoch,
    updatedAt: updatedAt.millisecondsSinceEpoch,
    version: version,
  );

  /// What an edit may change (ADR-0010). A null name writes NULL: the "use the default name again" edit.
  CategoriesTableCompanion toPatch() => CategoriesTableCompanion(name: Value(name), iconKey: Value(iconKey), colorKey: Value(colorKey));
}

/// Goes to the log, so a reason names a check and never a value from the row (golden rule 9).
enum CategoryMapperReason { unknownType, brokenDomainRule }
