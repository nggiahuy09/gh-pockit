import 'package:drift/drift.dart';

/// No SQL defaults, on purpose: on a synced row, a value nobody wrote would pass for one the server confirmed.
@DataClassName('AccountRow')
// No separate `(owner_id)` index: SQLite serves `WHERE owner_id = ?` from this one's leftmost column.
@TableIndex(name: 'accounts_owner_id_is_archived', columns: {#ownerId, #isArchived})
// Not final: drift generates a subclass in another library.
class AccountsTable extends Table {
  TextColumn get id => text()();

  TextColumn get ownerId => text()();

  TextColumn get name => text()();

  /// Not drift's `textEnum`, which stores the Dart name and makes renaming a value a silent data migration.
  TextColumn get type => text()();

  /// `check()`, not `withLength()`: drift enforces `withLength` only in Dart, never in the `CREATE TABLE`.
  TextColumn get currencyCode => text().check(currencyCode.length.equals(3))();

  IntColumn get initialBalance => integer()();

  BoolColumn get isArchived => boolean()();

  IntColumn get createdAt => integer()();

  /// Moves on every synced write: it is half the pull cursor.
  IntColumn get updatedAt => integer()();

  IntColumn get version => integer()();

  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  String get tableName => 'accounts';
}
