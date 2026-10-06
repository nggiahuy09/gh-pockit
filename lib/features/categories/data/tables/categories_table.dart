import 'package:drift/drift.dart';

@DataClassName('CategoryRow')
// Also serves owner-only reads as its leftmost prefix, so there is no `(owner_id)` index.
@TableIndex(name: 'categories_owner_id_type', columns: {#ownerId, #type})
// One row per seeded key and owner. SQLite treats NULLs as distinct in a unique index, so user-made rows (`name_key IS NULL`) never collide.
@TableIndex(name: 'categories_owner_id_name_key', columns: {#ownerId, #nameKey}, unique: true)
class CategoriesTable extends Table {
  /// UUID v7; a seeded row's is v5 over `owner_id|name_key`, so every device mints the same id for it (ADR-0002 amendment).
  TextColumn get id => text()();

  /// `localOwnerId` until W10.
  TextColumn get ownerId => text()();

  /// A translation key (`category.food`), never translated text (ADR-0004). Kept through a rename; null on a user-made category.
  TextColumn get nameKey => text().nullable()();

  /// What the user typed; wins over [nameKey]. Null on a seeded category nobody has renamed.
  TextColumn get name => text().nullable()();

  /// `CategoryType.storageValue`. Plain text, not `textEnum`, which stores the Dart name and would make a rename a data migration.
  TextColumn get type => text()();

  /// A key into the app's icon set (`food`), never a code point: one would break when the icon font changes.
  TextColumn get iconKey => text().nullable()();

  /// A key into the theme's palette, never a hex: a stored colour cannot follow dark mode.
  TextColumn get colorKey => text().nullable()();

  /// Written by the seeder. Provenance, not a lock: the user may rename, recolour and delete the row.
  BoolColumn get isSystem => boolean()();

  /// Epoch millis, UTC.
  IntColumn get createdAt => integer()();

  /// Epoch millis, UTC.
  IntColumn get updatedAt => integer()();

  /// Optimistic-concurrency token (§7): starts at 1, then only the server's response sets it.
  IntColumn get version => integer()();

  /// Soft-delete tombstone, epoch millis UTC. Not indexed: a user has tens of categories.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// Cross-column, so it cannot be a column's `.check()`.
  @override
  List<String> get customConstraints => ['CHECK (name_key IS NOT NULL OR name IS NOT NULL)'];

  /// Explicit, so renaming the Dart class cannot rename the table.
  @override
  String get tableName => 'categories';
}
