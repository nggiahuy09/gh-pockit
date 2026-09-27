import 'package:drift/drift.dart';
import 'package:ghpockit/features/accounts/data/tables/accounts_table.dart';
import 'package:ghpockit/features/categories/data/tables/categories_table.dart';

/// The third synced table (W4 T3), and the one every number in the app is computed from — balances (W6), summaries (W7), budgets (W24).
///
/// The §6 column set carries the same weight as on `accounts`, and that reasoning is not repeated here. What this table adds was decided in ADR-0009
/// before it was written, because most of it is constraints and SQLite cannot `ALTER` one — changing any of them later is a table rebuild:
///
/// - **One row per transfer.** `type = 'transfer'`, [accountId] is the source and [destinationAccountId] the destination. A transfer cannot be half-synced,
///   because there is no second half.
/// - **[amountMinor] is a positive magnitude and [type] is the sign.** A transfer is money out of one account and into another in a single row, so no sign
///   is right for both of its sides.
/// - **The schema holds what makes a row uninterpretable** — a transfer with no destination has no place in the balance formula — and nothing about
///   vocabulary. There is no `CHECK (type IN (...))`, because a new type would then be a rebuild; the mapper refuses an unknown value on read.
/// - **Foreign keys, no `ON DELETE`, checked immediately** — see [accountId].
/// - **Indexes follow their readers.** The four below are what the list query and its filters read (W4 T5); `(sync_status)` and `(updated_at)` wait for
///   P4, when something filters on them.
///
/// **Not here yet: `receipt_id`.** Blueprint §20 has it, and W9 T3 adds it with a real `ADD COLUMN` on a table that already holds data.
@DataClassName('TransactionRow')
// One index per way the list is narrowed, each ending `occurred_at, id`, so `ORDER BY occurred_at DESC, id DESC LIMIT n` reads straight off the index with
// no sort step however many rows match. `id` is the tie-breaker ADR-0011 requires for a stable order, and it has to be *in* the index for the order to come
// from it: the rowid every index carries is not the primary key here, because `id` is TEXT.
//
// Ascending on purpose. SQLite scans an index backwards for a DESC order at the same cost, and `IndexedColumn(orderBy: OrderingMode.desc)` would only add a
// way for the index and the query to disagree. `EXPLAIN QUERY PLAN` in `transactions_table_test.dart` holds all four to it.
//
// Not partial (`WHERE deleted_at IS NULL`), although every list query filters on exactly that. SQLite only picks a partial index when the query repeats its
// condition, so a forgotten filter becomes a silent full scan — and tombstones are rare in a personal ledger. Changing an index is a drop and a create, not
// a rebuild, so this waits for W8's numbers.
@TableIndex(name: 'transactions_owner_id_occurred_at_id', columns: {#ownerId, #occurredAt, #id})
@TableIndex(name: 'transactions_account_id_occurred_at_id', columns: {#accountId, #occurredAt, #id})
// The transfer-in side of every balance (ADR-0009). Without it, "money that arrived in this account" is a table scan.
@TableIndex(name: 'transactions_destination_account_id_occurred_at_id', columns: {#destinationAccountId, #occurredAt, #id})
@TableIndex(name: 'transactions_category_id_occurred_at_id', columns: {#categoryId, #occurredAt, #id})
class TransactionsTable extends Table {
  /// UUID v7, minted client-side before the insert (golden rule 4, ADR-0002). Not `clientDefault`, for the reason `accounts.id` gives.
  TextColumn get id => text()();

  /// `localOwnerId` until auth lands. Never null — see `core/database/owner_id.dart`.
  TextColumn get ownerId => text()();

  /// `TransactionType.storageValue` — `expense`, `income` or `transfer` — stored as plain text and converted by the mapper at T6 rather than by `textEnum`,
  /// for the reason `accounts.type` gives. No vocabulary CHECK (ADR-0009). `'transfer'` does appear in [customConstraints] as a literal, which is why
  /// `TransactionType` warns against renaming it.
  TextColumn get type => text()();

  /// The account money leaves (expense, transfer) or arrives in (income).
  ///
  /// **Checked immediately, not `DEFERRABLE INITIALLY DEFERRED`.** Deferring would let one pull page (W14) apply children before parents, but not across
  /// pages — those still have to arrive parents first — and it moves the failure from the statement that caused it to the `COMMIT`, where nothing says
  /// which row it was. Deferral is part of the constraint, so this is the one foreign-key property that cannot change later without a rebuild; immediate
  /// is the one that is easier to debug.
  ///
  /// `@ReferenceName` because two columns here reference `accounts`, and drift's generated manager names each reverse relation after the referencing table
  /// by default — the two would collide and drift would drop both. Nothing in the app uses the manager API (DAOs own every query), but a build that warns
  /// on every run is a build whose next real warning goes unread.
  @ReferenceName('transactions')
  TextColumn get accountId => text().references(AccountsTable, #id)();

  /// Where a transfer's money arrives. Set on every transfer and on nothing else — see [customConstraints].
  @ReferenceName('incomingTransfers')
  TextColumn get destinationAccountId => text().nullable().references(AccountsTable, #id)();

  /// What the transaction is filed under, or null for uncategorised. Never set on a transfer.
  ///
  /// The foreign key sees a soft-deleted category as present — the row is still there — which is what ADR-0010 wants: deleting a category leaves its
  /// transactions pointing at the tombstone, and readers show them as "Uncategorised".
  TextColumn get categoryId => text().nullable().references(CategoriesTable, #id)();

  /// Minor units, `int` (golden rule 2), and **always positive**: [type] says which way the money moves (ADR-0009). Zero is refused too — an entry that
  /// moves nothing is a typo.
  ///
  /// A `check()` on the column rather than a table constraint, so it lands in the `CREATE TABLE` beside the column it is about — the choice, and the reason,
  /// of `accounts.currency_code`.
  // Drift's own idiom for a column CHECK, which `recursive_getters` reads as recursion. This getter is never called: the generated
  // `$TransactionsTableTable` overrides it with a `GeneratedColumn` whose check is `ComparableExpr(amountMinor).isBiggerThanValue(0)`. `currency_code`
  // escapes the lint only because its self-reference goes through `.length`.
  // ignore: recursive_getters
  IntColumn get amountMinor => integer().check(amountMinor.isBiggerThanValue(0))();

  /// ISO-4217, with the CHECK `accounts.currency_code` has (ADR-0007): the code decides how [amountMinor] is read. That it equals the account's own currency
  /// is a fact about another row, so it is the repository's check (ADR-0010), not the schema's.
  TextColumn get currencyCode => text().check(currencyCode.length.equals(3))();

  /// When the money moved: an instant, epoch millis UTC (§6). Which day that is depends on the zone it is shown in, which is presentation's (ADR-0009).
  IntColumn get occurredAt => integer()();

  /// Free text the user typed, or null. No length CHECK: `TransactionEntity.noteMaxLength` is a business rule, and §3 keeps those out of SQL.
  TextColumn get note => text().nullable()();

  /// Epoch millis, UTC. Written from `GPClock`, never `DateTime.now()`.
  IntColumn get createdAt => integer()();

  /// Epoch millis, UTC. Half the pull cursor at W14 T2.
  IntColumn get updatedAt => integer()();

  /// Optimistic-concurrency token (§7). Starts at 1, set from the server's response, never bumped hopefully on the client.
  IntColumn get version => integer()();

  /// Soft-delete tombstone (golden rule 5). Not indexed, and not yet a partial-index condition — see the indexes above.
  IntColumn get deletedAt => integer().nullable()();

  /// `pending` or `synced` (ADR-0009). Every local write sets `pending`; only the sync engine writes `synced`, from W13. No default, like every column here —
  /// a default would be a sync state nobody wrote — and no vocabulary CHECK.
  TextColumn get syncStatus => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// Cross-column, so none of them can be a `.check()` on one column. Each keeps a row readable by the balance formula of ADR-0009:
  ///
  /// 1. A transfer has a destination, and nothing else does.
  /// 2. Money does not move from an account into itself. NULL passes, which is what a non-transfer needs.
  /// 3. A transfer is spending in no category.
  @override
  List<String> get customConstraints => [
    "CHECK ((type = 'transfer') = (destination_account_id IS NOT NULL))",
    'CHECK (destination_account_id <> account_id)',
    "CHECK (type <> 'transfer' OR category_id IS NULL)",
  ];

  /// Stated, not derived — a Dart rename must not become a schema change behind the author's back.
  @override
  String get tableName => 'transactions';
}
