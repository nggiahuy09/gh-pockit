import 'package:drift/drift.dart';

@DataClassName('CategoryRow')
// Also serves owner-only reads as its leftmost prefix, so there is no `(owner_id)` index.
@TableIndex(name: 'categories_owner_id_type', columns: {#ownerId, #type})
// One row per seeded key and owner. SQLite treats NULLs as distinct in a unique index, so user-made rows (`name_key IS NULL`) never collide.
@TableIndex(name: 'categories_owner_id_name_key', columns: {#ownerId, #nameKey}, unique: true)
// Not final: drift generates a subclass in another library.
class CategoriesTable extends Table {
  /// A seeded row's is v5 over `owner_id|name_key`, so every device mints the same id for it (ADR-0002 amendment).
  TextColumn get id => text()();

  TextColumn get ownerId => text()();

  /// A translation key, never translated text (ADR-0004).
  TextColumn get nameKey => text().nullable()();

  TextColumn get name => text().nullable()();

  /// Not `textEnum`, which stores the Dart name and would make a rename a data migration.
  TextColumn get type => text()();

  /// Never a code point: one would break when the icon font changes.
  TextColumn get iconKey => text().nullable()();

  /// Never a hex: a stored colour cannot follow dark mode.
  TextColumn get colorKey => text().nullable()();

  BoolColumn get isSystem => boolean()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  IntColumn get version => integer()();

  /// Not indexed: a user has tens of categories.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (name_key IS NOT NULL OR name IS NOT NULL)'];

  @override
  String get tableName => 'categories';
}
