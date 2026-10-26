import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import 'category_type.dart';

/// At least one of [nameKey] and [name] is set: a seeded category has a key, a user-made one a name, a renamed seed both. Resolving a key needs the
/// locale, so the display name lives in presentation (ADR-0004).
@immutable
final class CategoryEntity with Equatable {
  const CategoryEntity._({
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    required this.colorKey,
    required this.iconKey,
    required this.id,
    required this.name,
    required this.nameKey,
    required this.version,
    required this.isSystem,
  });

  static GPResult<CategoryEntity> create({
    required CategoryType type,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? colorKey,
    String? iconKey,
    required String id,
    String? name,
    String? nameKey,
    int version = 1,
    bool isSystem = false,
  }) {
    final trimmedName = name?.trim();
    final normalizedName = (trimmedName == null || trimmedName.isEmpty) ? null : trimmedName;
    if (normalizedName == null && nameKey == null) return const GPErr(GPValidationFailure(GPValidationCode.categoryNameEmpty));
    if (normalizedName != null && normalizedName.length > nameMaxLength) return const GPErr(GPValidationFailure(GPValidationCode.categoryNameTooLong));

    return GPOk(
      CategoryEntity._(
        type: type,
        createdAt: createdAt.toUtc(),
        updatedAt: updatedAt.toUtc(),
        colorKey: colorKey,
        iconKey: iconKey,
        id: id,
        name: normalizedName,
        nameKey: nameKey,
        version: version,
        isSystem: isSystem,
      ),
    );
  }

  final CategoryType type;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Null means colour by [type], as every seeded category does.
  final String? colorKey;

  final String? iconKey;
  final String id;

  /// Wins over [nameKey] wherever a name is shown. Never `''`.
  final String? name;

  final String? nameKey;

  /// The server's optimistic-concurrency token: the client never increments it.
  final int version;

  /// Provenance, not a lock: a system category can be renamed and deleted like any other.
  final bool isSystem;

  static const nameMaxLength = 100;

  @override
  List<Object?> get props => [type, createdAt, updatedAt, colorKey, iconKey, id, name, nameKey, version, isSystem];

  /// Null keeps a field; [clearName] falls a renamed seed back to its default name. Provenance and [type] never change (ADR-0010).
  GPResult<CategoryEntity> update({String? colorKey, String? iconKey, String? name, int? version, bool clearName = false}) => create(
    type: type,
    createdAt: createdAt,
    updatedAt: updatedAt,
    colorKey: colorKey ?? this.colorKey,
    iconKey: iconKey ?? this.iconKey,
    id: id,
    name: clearName ? null : (name ?? this.name),
    nameKey: nameKey,
    version: version ?? this.version,
    isSystem: isSystem,
  );

  CategoryEntity withUpdatedAt(DateTime updatedAt) => CategoryEntity._(
    type: type,
    createdAt: createdAt,
    updatedAt: updatedAt.toUtc(),
    colorKey: colorKey,
    iconKey: iconKey,
    id: id,
    name: name,
    nameKey: nameKey,
    version: version,
    isSystem: isSystem,
  );

  /// No [name]: user-typed text never reaches a log (golden rule 9).
  @override
  String toString() => 'CategoryEntity(id: $id, nameKey: $nameKey, type: ${type.name}, isSystem: $isSystem, version: $version)';
}
