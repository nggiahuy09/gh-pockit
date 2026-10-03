import 'package:drift/drift.dart';

/// The second synced table (W3 T5), and the first one whose display name is **not** a string in a column.
///
/// The §6 column set is the same as `accounts` and carries the same weight — `owner_id`, `version`, `deleted_at`, `created_at`, `updated_at` — so the
/// reasoning in `accounts_table.dart` is not repeated here. What is specific to this table is the name.
///
/// **A category has two name columns and at least one of them is set.**
///
/// - [nameKey] holds a translation key, `category.food`, for the rows the app seeds. It is never a translated string: a Vietnamese user who switches the
///   app to English must see "Food", not "Ăn uống" frozen at install time, and `INSERT`ing the translated text is the one decision that makes that
///   impossible to fix later (ADR-0004).
/// - [name] holds text the user typed. A category they created has only this. A seeded category they renamed has both, and **the typed name wins** — the
///   key stays so the row is still recognisably "the food one" for a later migration or for analytics.
///
/// `CHECK (name_key IS NOT NULL OR name IS NOT NULL)` is what makes "at least one" a property of the database rather than of whoever wrote the last insert.
/// It is a storage-integrity constraint in the same sense as the currency CHECK on `accounts`: without it a row can exist that no screen can render, and
/// the failure surfaces as a blank line in a picker rather than as a rejected write.
///
/// **Why not one nullable `name` plus `is_system`.** Because renaming a seeded category would then have to overwrite the key, and the row would stop being
/// identifiable as the default it came from — the information loss is silent and permanent. Two columns cost eight bytes and keep both facts.
@DataClassName('CategoryRow')
// The picker query: every live category of one owner, split into expense and income. `(owner_id, type)` serves both that and the owner-only prefix, for the
// same leftmost-prefix reason `accounts` gives for not adding a second index on `(owner_id)` alone.
@TableIndex(name: 'categories_owner_id_type', columns: {#ownerId, #type})
// **Unique, and the uniqueness is the seeding contract.** A seeded row's id is derived from `(owner_id, name_key)`, so re-running the seeder writes the same
// primary key and is ignored; this index is the second lock on the same door, for the case where a row reaches the table some other way — a pull at W14, or
// a future "restore default categories".
//
// It reads as a *partial* unique index without being one: SQLite treats NULLs as distinct in a unique index, so any number of user-created rows (`name_key
// IS NULL`) coexist, while two rows claiming `category.food` for one owner cannot.
@TableIndex(name: 'categories_owner_id_name_key', columns: {#ownerId, #nameKey}, unique: true)
class CategoriesTable extends Table {
  /// UUID. For a user-created category it is `GPUuidGenerator.v7`, as everywhere else; for a seeded one it is `v5` over `owner_id|name_key`, so that two
  /// devices belonging to the same user mint the *same* id for "Food" and a pull reconciles them instead of showing the user two of everything. See
  /// `category_seeder.dart`.
  TextColumn get id => text()();

  /// `localOwnerId` until W10. Never null — see `core/database/owner_id.dart`.
  TextColumn get ownerId => text()();

  /// Translation key for a seeded category (`category.food`), null for one the user created. Never translated text — see the class doc.
  TextColumn get nameKey => text().nullable()();

  /// The name the user typed, and the one that wins when both are present. Null on a seeded category nobody has renamed.
  TextColumn get name => text().nullable()();

  /// `CategoryType` — `expense` or `income` — stored as plain text and converted by the mapper at T6, not `textEnum<CategoryType>()`. Same reasoning as
  /// `accounts.type`: `textEnum` persists the Dart constant's name, which turns a rename into a silent data migration.
  TextColumn get type => text()();

  /// A key into the app's icon set, resolved in presentation — `icon_food`, not a code point. A stored code point is a number that means nothing after the
  /// icon font changes, and Material's identifiers are not stable enough to put in a database.
  TextColumn get iconKey => text().nullable()();

  /// A key into the theme's palette, resolved in presentation. Never `#FF5722`: a stored hex is a colour that ignores dark mode and cannot be re-themed.
  TextColumn get colorKey => text().nullable()();

  /// True for the rows the seeder wrote. It is not a permission — the user may rename, recolour and soft-delete a system category — it is provenance, and
  /// W6 uses it to offer "restore defaults" and to keep a fresh install's categories out of the "you created these" list.
  BoolColumn get isSystem => boolean()();

  /// Epoch millis, UTC (§6). Written from `GPClock`, never `DateTime.now()`.
  IntColumn get createdAt => integer()();

  /// Epoch millis, UTC. Half the pull cursor at W14 T2.
  IntColumn get updatedAt => integer()();

  /// Optimistic-concurrency token (§7). Starts at 1, set from the server's response, never bumped hopefully on the client.
  IntColumn get version => integer()();

  /// Soft-delete tombstone (golden rule 5). Not indexed, same as `accounts`: a user has tens of categories, and an index nothing needs is one every write
  /// maintains.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// Cross-column, so it cannot be written as a `.check()` on either column the way `accounts.currency_code` is.
  @override
  List<String> get customConstraints => ['CHECK (name_key IS NOT NULL OR name IS NOT NULL)'];

  /// Stated, not derived — a Dart rename must not become a schema change behind the author's back.
  @override
  String get tableName => 'categories';
}
