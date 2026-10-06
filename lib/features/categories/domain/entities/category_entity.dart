import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:meta/meta.dart';

/// [nameKey] and [name] are both nullable and at least one is set: a seeded category has a key, a user-made one a name, a renamed seed both.
/// No display name here: resolving a key needs the active locale, so that is `displayNameIn` in presentation (ADR-0004).
@immutable
final class CategoryEntity {
  const CategoryEntity._({
    required this.id,
    required this.nameKey,
    required this.name,
    required this.type,
    required this.iconKey,
    required this.colorKey,
    required this.isSystem,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  /// In UTF-16 code units. The only cap: `categories.name` is unbounded `TEXT` that syncs to every device.
  static const int nameMaxLength = 100;

  final String id;

  /// Translation key (`category.food`) of a seeded category, null for a user-made one. Survives a rename.
  final String? nameKey;

  /// What the user typed, trimmed; wins over [nameKey] wherever a name is shown. Never `''`: [create] turns a blank name into null.
  final String? name;

  final CategoryType type;

  /// A key into the app's icon set (`food`), resolved in presentation. Not a code point.
  final String? iconKey;

  /// A key into the theme's palette, resolved in presentation. Null means colour by [type], as every seeded category does.
  final String? colorKey;

  /// Seeded by the app. Provenance, not a lock: a system category can be renamed, recoloured and deleted like any other.
  final bool isSystem;

  /// Always UTC.
  final DateTime createdAt;

  /// Always UTC. Restamped by the repository on every write.
  final DateTime updatedAt;

  /// Optimistic-concurrency token (§7): the server's number, sent back as `baseVersion`. The client never increments it.
  final int version;

  /// Trims [name], a blank one counting as absent. Fails with a [GPValidationFailure] when neither a name nor [nameKey] is left, or the name is too long.
  static GPResult<CategoryEntity> create({
    required String id,
    required CategoryType type,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? nameKey,
    String? name,
    String? iconKey,
    String? colorKey,
    bool isSystem = false,
    int version = 1,
  }) {
    final trimmedName = name?.trim();
    final normalizedName = (trimmedName == null || trimmedName.isEmpty) ? null : trimmedName;

    if (normalizedName == null && nameKey == null) return const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameEmpty));

    if (normalizedName != null && normalizedName.length > nameMaxLength) return const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameTooLong));

    return GPOk<CategoryEntity>(
      CategoryEntity._(
        id: id,
        nameKey: nameKey,
        name: normalizedName,
        type: type,
        iconKey: iconKey,
        colorKey: colorKey,
        isSystem: isSystem,
        createdAt: createdAt.toUtc(),
        updatedAt: updatedAt.toUtc(),
        version: version,
      ),
    );
  }

  /// Null keeps a field, so [clearName] is how a renamed seed falls back to its default name. No parameter for [nameKey] or [isSystem], on purpose:
  /// an edit never changes provenance. [updatedAt] is the repository's to restamp ([stampedAt]).
  GPResult<CategoryEntity> update({
    String? name,
    CategoryType? type,
    String? iconKey,
    String? colorKey,
    int? version,
    bool clearName = false,
  }) => create(
    id: id,
    nameKey: nameKey,
    name: clearName ? null : (name ?? this.name),
    type: type ?? this.type,
    iconKey: iconKey ?? this.iconKey,
    colorKey: colorKey ?? this.colorKey,
    isSystem: isSystem,
    createdAt: createdAt,
    updatedAt: updatedAt,
    version: version ?? this.version,
  );

  CategoryEntity stampedAt(DateTime updatedAt) => CategoryEntity._(
    id: id,
    nameKey: nameKey,
    name: name,
    type: type,
    iconKey: iconKey,
    colorKey: colorKey,
    isSystem: isSystem,
    createdAt: createdAt,
    updatedAt: updatedAt.toUtc(),
    version: version,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryEntity &&
          other.id == id &&
          other.nameKey == nameKey &&
          other.name == name &&
          other.type == type &&
          other.iconKey == iconKey &&
          other.colorKey == colorKey &&
          other.isSystem == isSystem &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt &&
          other.version == version;

  @override
  int get hashCode => Object.hash(id, nameKey, name, type, iconKey, colorKey, isSystem, createdAt, updatedAt, version);

  /// No [name]: user-typed text never reaches a log (golden rule 9). [nameKey] is our own constant.
  @override
  String toString() => 'CategoryEntity(id: $id, nameKey: $nameKey, type: ${type.name}, isSystem: $isSystem, version: $version)';
}
