import 'package:drift/drift.dart';
import 'package:ghpockit/features/accounts/data/tables/accounts_table.dart';
import 'package:ghpockit/features/categories/data/tables/categories_table.dart';

/// Constraints follow ADR-0009. SQLite cannot `ALTER` a constraint, so changing one later is a table rebuild.
@DataClassName('TransactionRow')
// Each index ends `occurred_at, id`, so `ORDER BY occurred_at DESC, id DESC LIMIT n` needs no sort. `id` must be listed: with a TEXT primary key, the rowid
// every index carries is not `id`. Ascending on purpose — SQLite scans backwards for DESC at the same cost. Not partial on `deleted_at IS NULL`: SQLite only
// uses a partial index when the query repeats its condition, so a forgotten filter would become a silent full scan.
@TableIndex(name: 'transactions_owner_id_occurred_at_id', columns: {#ownerId, #occurredAt, #id})
@TableIndex(name: 'transactions_account_id_occurred_at_id', columns: {#accountId, #occurredAt, #id})
@TableIndex(name: 'transactions_destination_account_id_occurred_at_id', columns: {#destinationAccountId, #occurredAt, #id})
@TableIndex(name: 'transactions_category_id_occurred_at_id', columns: {#categoryId, #occurredAt, #id})
class TransactionsTable extends Table {
  TextColumn get id => text()();

  TextColumn get ownerId => text()();

  /// `TransactionType.storageValue`, with no vocabulary CHECK (ADR-0009). `'transfer'` is a literal in [customConstraints]: never rename it.
  TextColumn get type => text()();

  /// Foreign keys are checked immediately, not deferred: a violation fails its own statement instead of the `COMMIT`. `@ReferenceName` because two columns
  /// reference `accounts`, and drift's default reverse-relation names would collide.
  @ReferenceName('transactions')
  TextColumn get accountId => text().references(AccountsTable, #id)();

  @ReferenceName('incomingTransfers')
  TextColumn get destinationAccountId => text().nullable().references(AccountsTable, #id)();

  /// The foreign key accepts a soft-deleted category on purpose: its transactions keep the id and read as "Uncategorised" (ADR-0010).
  TextColumn get categoryId => text().nullable().references(CategoriesTable, #id)();

  /// Always positive: [type] gives the direction (ADR-0009).
  // Drift's idiom for a column CHECK, which `recursive_getters` reads as recursion; the generated table overrides this getter.
  // ignore: recursive_getters
  IntColumn get amountMinor => integer().check(amountMinor.isBiggerThanValue(0))();

  /// That it equals the account's currency is a fact about another row, so the repository checks it, not the schema (ADR-0010).
  TextColumn get currencyCode => text().check(currencyCode.length.equals(3))();

  /// An instant; which local day it falls on is presentation's (ADR-0009).
  IntColumn get occurredAt => integer()();

  /// No length CHECK: `TransactionEntity.noteMaxLength` is a domain rule.
  TextColumn get note => text().nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  /// Set from the server's response, never bumped on the client (§7).
  IntColumn get version => integer()();

  IntColumn get deletedAt => integer().nullable()();

  /// `pending` or `synced`. Local writes set `pending`; only the sync engine writes `synced`. No default: that would be a sync state nobody wrote.
  TextColumn get syncStatus => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// The first CHECK compares two booleans: a transfer has a destination, and nothing else does. NULL passes the second, as a non-transfer needs.
  @override
  List<String> get customConstraints => [
    "CHECK ((type = 'transfer') = (destination_account_id IS NOT NULL))",
    'CHECK (destination_account_id <> account_id)',
    "CHECK (type <> 'transfer' OR category_id IS NULL)",
  ];

  /// Stated, not derived: a Dart rename must not become a schema change.
  @override
  String get tableName => 'transactions';
}
