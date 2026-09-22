import 'package:drift/drift.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';

/// Why a stored `categories` row could not be read.
///
/// Two reasons where `accounts` has three — there is no currency here. Both flatten to the same [GPDatabaseFailure] for the user and stay distinct in the
/// log, for the reason `AccountMapperReason` sets out: one undifferentiated cluster in P7's crash reports tells nobody whether a schema drifted or a file
/// corrupted. A reason names a *check*, never a value, so golden rule 9 holds.
enum CategoryMapperReason {
  /// `type` held a string no [CategoryType] knows — a row from a newer build, or a corrupted one.
  unknownType,

  /// The row parsed but broke a domain rule: both name columns null. The table's `CHECK` makes that unreachable through SQL, so reaching it means a row
  /// arrived by some route that bypassed the schema — a restored backup from a build before the constraint, most plausibly.
  brokenDomainRule,
}

/// The outcome of reading one `categories` row. Sealed pair rather than a `GPResult`, for the reason `AccountMapping` gives.
sealed class CategoryMapping {
  const CategoryMapping();
}

/// The row was read.
final class MappedCategory extends CategoryMapping {
  const MappedCategory(this.category);

  final CategoryEntity category;
}

/// The row was not read, and [reason] says which check refused it.
final class UnmappableCategoryRow extends CategoryMapping {
  const UnmappableCategoryRow(this.reason);

  final CategoryMapperReason reason;

  /// Always [GPDatabaseFailure]: the user is looking at a list, not at a form, so the only true sentence is that local data cannot be read.
  GPFailure get failure => const GPDatabaseFailure();
}

/// The one place that knows how a `categories` row becomes a [CategoryEntity] and back (W3 T6).
///
/// Three translations, and one deliberate omission:
///
/// - **`type` ↔ [CategoryType]** through `storageValue`, not drift's `textEnum` — the table refuses `textEnum` so a Dart rename cannot orphan every row.
/// - **epoch millis ↔ `DateTime`**, always UTC (§6).
/// - **`owner_id` appears out of nowhere** in [toInsert], because it is not on the entity and only the repository knows it.
/// - **`name_key` is absent from [toPatch].** The omission is the mechanism: there is no path from a user edit to that column, so "a rename keeps the key"
///   holds even if a future caller builds a patch by hand.
///
/// Row → entity can fail, entity → row cannot. Stateless and `const`, so the repository holds one as a default argument rather than DI registering it.
class CategoryMapper {
  const CategoryMapper();

  /// Parses a row into a [MappedCategory], or an [UnmappableCategoryRow] naming the check that refused it.
  ///
  /// Tombstones are not filtered here, same as `AccountMapper.toEntity`: the DAO's reads already do it, and `findById` deliberately does not because W13's
  /// applier needs the tombstone.
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

  /// Builds the companion for a fresh insert — every column stated, nothing defaulted.
  ///
  /// `.insert` rather than the unnamed constructor, so a column added to the table without a value here is a compile error rather than an absent value on a
  /// synced row.
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

  /// Builds the patch for an update: only the columns a user edit may move.
  ///
  /// Six columns are absent. `id` and `created_at` are identity; `owner_id` is not the entity's to state; `version` is the server's (§7); `updated_at` is
  /// stamped by `CategoryDao.updateCategory` so a patch cannot skip the pull cursor; and `name_key` and `is_system` are provenance — see the class doc.
  ///
  /// `Value(entity.name)` writes NULL when the user cleared their custom name, which is the "use the default again" edit. The table's `CHECK` is what makes
  /// that safe to express: it can only be reached on a row that has a key.
  CategoriesTableCompanion toPatch(CategoryEntity entity) => CategoriesTableCompanion(
    name: Value(entity.name),
    type: Value(entity.type.storageValue),
    iconKey: Value(entity.iconKey),
    colorKey: Value(entity.colorKey),
  );
}
