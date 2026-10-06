import 'package:drift/drift.dart';

/// No SQL defaults, on purpose: on a synced row, a value nobody wrote would pass for one the server confirmed.
@DataClassName('AccountRow')
// No separate `(owner_id)` index: SQLite serves `WHERE owner_id = ?` from this one's leftmost column.
@TableIndex(name: 'accounts_owner_id_is_archived', columns: {#ownerId, #isArchived})
class AccountsTable extends Table {
  /// Minted by the repository before the insert (ADR-0002), not by a `clientDefault`.
  TextColumn get id => text()();

  /// `localOwnerId` until auth lands; see `core/database/owner_id.dart`.
  TextColumn get ownerId => text()();

  /// No length CHECK: the limit is a domain rule, `AccountEntity.nameMaxLength`.
  TextColumn get name => text()();

  /// `AccountType.storageValue`. Not drift's `textEnum`, which stores the Dart name and makes renaming a value a silent data migration.
  TextColumn get type => text()();

  /// ISO 4217; it decides how [initialBalance] is read, hence the CHECK. `check()`, not `withLength()`: drift enforces `withLength` only in Dart, never
  /// in the `CREATE TABLE`.
  TextColumn get currencyCode => text().check(currencyCode.length.equals(3))();

  /// Minor units: $12.34 is `1234`. The opening balance; the current one is computed, never stored.
  IntColumn get initialBalance => integer()();

  BoolColumn get isArchived => boolean()();

  /// Epoch millis, UTC.
  IntColumn get createdAt => integer()();

  /// Epoch millis, UTC. Moves on every synced write: it is half the pull cursor.
  IntColumn get updatedAt => integer()();

  IntColumn get version => integer()();

  /// Epoch millis, UTC; null while live.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  String get tableName => 'accounts';
}
