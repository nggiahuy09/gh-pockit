import 'package:drift/drift.dart';

import '../../../accounts/data/tables/accounts_table.dart';
import '../../../categories/data/tables/categories_table.dart';

/// Constraints follow ADR-0009. SQLite cannot `ALTER` a constraint, so changing one later is a table rebuild.
@DataClassName('TransactionRow')
// Each index ends `occurred_at, id` so the list's ORDER BY needs no sort; `id` must be listed, the rowid of a TEXT key is not `id`. Not partial on
// `deleted_at IS NULL`: SQLite uses a partial index only when the query repeats its condition.
@TableIndex(name: 'transactions_owner_id_occurred_at_id', columns: {#ownerId, #occurredAt, #id})
@TableIndex(name: 'transactions_account_id_occurred_at_id', columns: {#accountId, #occurredAt, #id})
@TableIndex(name: 'transactions_destination_account_id_occurred_at_id', columns: {#destinationAccountId, #occurredAt, #id})
@TableIndex(name: 'transactions_category_id_occurred_at_id', columns: {#categoryId, #occurredAt, #id})
// Not final: drift generates a subclass in another library.
class TransactionsTable extends Table {
  TextColumn get id => text()();

  TextColumn get ownerId => text()();

  /// No vocabulary CHECK (ADR-0009). `'transfer'` is a literal in [customConstraints]: never rename it.
  TextColumn get type => text()();

  /// `@ReferenceName` because two columns reference `accounts`, and drift's default reverse-relation names would collide.
  @ReferenceName('transactions')
  TextColumn get accountId => text().references(AccountsTable, #id)();

  @ReferenceName('incomingTransfers')
  TextColumn get destinationAccountId => text().nullable().references(AccountsTable, #id)();

  /// Accepts a soft-deleted category on purpose: its transactions read as "Uncategorised" (ADR-0010).
  TextColumn get categoryId => text().nullable().references(CategoriesTable, #id)();

  // Drift's idiom for a column CHECK, which `recursive_getters` reads as recursion; the generated table overrides this getter.
  // ignore: recursive_getters
  IntColumn get amountMinor => integer().check(amountMinor.isBiggerThanValue(0))();

  TextColumn get currencyCode => text().check(currencyCode.length.equals(3))();

  IntColumn get occurredAt => integer()();

  TextColumn get note => text().nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  IntColumn get version => integer()();

  IntColumn get deletedAt => integer().nullable()();

  /// No default: that would be a sync state nobody wrote.
  TextColumn get syncStatus => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// The first CHECK compares two booleans: a transfer has a destination, and nothing else does.
  @override
  List<String> get customConstraints => [
    "CHECK ((type = 'transfer') = (destination_account_id IS NOT NULL))",
    'CHECK (destination_account_id <> account_id)',
    "CHECK (type <> 'transfer' OR category_id IS NULL)",
  ];

  @override
  String get tableName => 'transactions';
}
