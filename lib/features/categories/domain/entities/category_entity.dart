import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:meta/meta.dart';

/// What a transaction is filed under (blueprint §Categories).
///
/// The row/entity split is the one `AccountEntity` documents — no `ownerId`, no `deletedAt`, `DateTime` instead of epoch millis, `version` visible because
/// §7 makes conflicts a user-facing outcome. What is different here is the name, and it is different in a way the type has to carry rather than hide:
///
/// | | [nameKey] | [name] |
/// | --- | --- | --- |
/// | Seeded, untouched | `category.food` | null |
/// | Seeded, renamed | `category.food` | `'Cà phê sáng'` |
/// | Created by the user | null | `'Cà phê'` |
///
/// **Both are nullable and at least one is set** — the invariant [create] enforces and `categories`' `CHECK` enforces one layer down. A reader who wants
/// text calls `categoryDisplayName` in presentation, because resolving a key needs the active locale and the domain carries no message (ADR-0004).
///
/// **The entity deliberately cannot resolve its own name.** A `String get displayName` here would need a `GPLocaleBase`, which would put a Flutter-adjacent
/// import in `domain/` (§3) — and would also make an entity's equality depend on the language, so switching from English to Vietnamese would make every
/// category "change" and rebuild the whole list.
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

  /// Longest user-typed name accepted, in UTF-16 code units. Same limit and same reasoning as `AccountEntity.nameMaxLength`: `categories.name` is unbounded
  /// `TEXT` that syncs, so without a limit a pasted document becomes a row pushed to every other device.
  static const int nameMaxLength = 100;

  final String id;

  /// The translation key of a seeded category, null for one the user created.
  ///
  /// **Never changed by an edit.** A user renaming "Food" to "Cà phê sáng" keeps this, so the row is still recognisably the default it came from — for a
  /// later migration, for analytics, and for `CategorySeeder`'s idempotency, which matches on an id derived from exactly this key.
  final String? nameKey;

  /// The name the user typed, trimmed, and **the one that wins** wherever a name is shown. Null when nobody has typed one.
  ///
  /// Empty is normalised to null by [create], so `''` and "no name" are one state rather than two that render identically and compare differently.
  final String? name;

  final CategoryType type;

  /// A key into the app's icon set, resolved in presentation. Not a code point — see `categories_table.dart`.
  final String? iconKey;

  /// A key into the theme's palette, resolved in presentation. Null means "colour me by [type]", which is what the seeded categories do.
  final String? colorKey;

  /// Provenance, not a permission: a system category can be renamed, recoloured and deleted like any other. It is what lets W6 offer "restore defaults"
  /// and keep a fresh install's categories out of the "you created these" list.
  final bool isSystem;

  /// UTC, always. [create] normalises.
  final DateTime createdAt;

  /// UTC. Half the pull cursor at W14 T2, stamped by the repository from `GPClock`.
  final DateTime updatedAt;

  /// Optimistic-concurrency token (§7). The server's number; the client sends it back as `baseVersion` and never increments it.
  final int version;

  /// The only way to build a [CategoryEntity], and the only place the name rules live.
  ///
  /// Returns a [GPResult] rather than throwing, because the rule it enforces is one an ordinary user trips by pressing Save on an empty field — ADR-0006's
  /// dividing line. Used by `CategoryMapper` too, so a row that went bad is caught at the boundary rather than flowing into a picker as a nameless entry.
  ///
  /// Three things happen to [name] before it is stored: it is trimmed, an empty result becomes null, and only then is the length checked. The middle step is
  /// what makes `'   '` mean "no name" instead of a three-character one.
  ///
  /// [GPValidationCode.categoryNameEmpty] is returned when **both** names are absent. That is the same invariant as the table's `CHECK`, stated where a user
  /// can be told about it: for a user-created category it means "you left the name blank", which is exactly the message they get.
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

  /// A copy with some fields changed, re-validated.
  ///
  /// **[nameKey], [isSystem], [id] and [createdAt] are all absent, and each for its own reason.** The last two are identity — an entity that can change them
  /// is one the sync engine can no longer match to a server row. `nameKey` and `isSystem` are *provenance*: they record where the row came from, and an edit
  /// is not a change of origin. Leaving them out of this signature is what makes "a rename keeps the key" true by construction instead of by convention.
  ///
  /// [updatedAt] is absent for the reason `AccountEntity.update` spells out at length: the only correct value is "now", and only the repository holds a
  /// clock. Restamping is [stampedAt].
  ///
  /// **[clearName] exists because `null` already means "leave it alone".** Setting a system category's name back to null — "use the default name again" — is
  /// a real edit a settings screen offers, and with optional parameters alone it is unexpressible. A flag is uglier than a sentinel and impossible to pass
  /// by accident.
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

  /// The same category with a new [updatedAt]. Cannot fail, because nothing validated changes — so not a [GPResult], for the reason
  /// `AccountEntity.stampedAt` gives.
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

  /// Value equality over every field, so a Drift stream re-emitting freshly mapped instances does not rebuild every category widget on screen.
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

  /// **Carries no [name], deliberately** — golden rule 9, same as `AccountEntity.toString`. [nameKey] is safe and is the useful half anyway: it is our own
  /// constant, not something a user typed, and it is what identifies the row in a log. A renamed category logs its key and not the rename.
  @override
  String toString() => 'CategoryEntity(id: $id, nameKey: $nameKey, type: ${type.name}, isSystem: $isSystem, version: $version)';
}
