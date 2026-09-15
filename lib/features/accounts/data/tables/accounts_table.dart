import 'package:drift/drift.dart';

/// The first **synced** table in the app (W2 T3) — and therefore the first one that has to carry the full §6 column set.
///
/// `settings` next door is the counter-example: local-only, so it needs none of `owner_id`, `version` or `deleted_at`. Everything here does, because every
/// row will one day be pushed through the outbox, matched against a server row, and reconciled. The columns below are not bookkeeping; each one is load
/// bearing for a rule that only shows up in P4:
///
/// - `owner_id` — row-level ownership, mirrored by the Supabase RLS policy of W10 T4. Until auth exists it holds `localOwnerId`; see that constant for why
///   the column is `NOT NULL` from day one rather than nullable-then-backfilled.
/// - `version` — the optimistic-concurrency token of §7. The client pushes it as `baseVersion`, the server runs `UPDATE ... WHERE version = ?`, and zero
///   affected rows means a conflict. A row whose `version` is wrong is a row that silently overwrites another device.
/// - `deleted_at` — soft delete (golden rule 5). A hard `DELETE` here would be a row the server never learns is gone.
/// - `created_at` / `updated_at` — epoch millis, UTC (§6). `updated_at` is half the pull cursor of W12 T2 (`updated_at, id`), which is why it is `NOT NULL`
///   and why nothing may write it from `DateTime.now()` instead of `GPClock`.
///
/// **No SQL defaults, deliberately.** Not on `version`, not on `is_archived`, not on the timestamps. A default is a value nobody wrote, and on a synced row
/// that is indistinguishable from a value the server confirmed — `version` defaulting to 1 would let a row claim a base version it never had. Every insert
/// states all of it; §12 has no rule for this yet because nothing had a `version` column before today.
///
/// **On the name.** `AccountsTable`, unprefixed, under `features/accounts/data/` — §3 files rows next to DTOs and mappers, not next to `core/` types, and
/// `GPAppDatabase` importing it is the one direction that is allowed: the database is a schema registry, so it collects inert row declarations. Nothing in
/// `core/` imports an `AccountDao`, an `AccountRepositoryImpl` or an `Account`, and that is the line that keeps §3 true.
@DataClassName('AccountRow')
// Only the composite index, which is a documented divergence from blueprint §accounts — it lists `(owner_id)` as well.
//
// SQLite can use any leftmost prefix of a composite index, so `WHERE owner_id = ?` is already served by the index below; a second index on `(owner_id)`
// alone would be read by nothing and re-written on every insert, update and soft delete. The blueprint's intent — "filtering by owner, and by owner plus
// archived state, must not be a table scan" — is met in full. Dropping it later would itself cost a migration, so it is not created now.
//
// Explicit name rather than drift's derived one: the index name is what `EXPLAIN QUERY PLAN` prints in W8, and what a migration has to `DROP` by hand.
@TableIndex(name: 'accounts_owner_id_is_archived', columns: {#ownerId, #isArchived})
class AccountsTable extends Table {
  /// UUID, generated client-side by `GPUuidGenerator` before the insert (golden rule 4, ADR-0002).
  ///
  /// Not `clientDefault`: drift would then mint the id inside the insert, and the repository would have to read the row back to learn what it just wrote —
  /// which is the round trip client-side ids exist to remove. The caller generates it, the caller keeps it, the outbox references it.
  TextColumn get id => text()();

  /// `localOwnerId` until W10. Never null — see `core/database/owner_id.dart`.
  TextColumn get ownerId => text()();

  /// User-facing, user-editable. No length constraint here on purpose: "an account name may not be blank" is a business rule, and §3 puts business rules in
  /// `domain/` where T5's `Account` can state it once for every caller, not in a CHECK that only the DB path enforces.
  TextColumn get name => text()();

  /// `AccountType` as of T5, stored as plain text and converted by `AccountMapper` at T6 — not `textEnum<AccountType>()`.
  ///
  /// `textEnum` persists the Dart constant's *name*, which turns renaming an enum value into a silent data migration: the code compiles, the old rows stop
  /// matching, and nothing fails until a user notices their accounts lost their type. An explicit mapper makes the stored vocabulary a thing a reviewer can
  /// see in a diff, and it is also what §3's three-model rule asks for — the row and the entity are allowed to disagree about representation.
  TextColumn get type => text()();

  /// ISO-4217, e.g. `VND`, `USD`.
  ///
  /// The one hand-written CHECK on this table, and the reason it is not "domain validation leaking into the DB": this column decides how [initialBalance]
  /// is read. VND has exponent 0 and USD exponent 2, so a malformed code makes the integer next to it un-interpretable rather than merely invalid. That is
  /// a storage-integrity property, and W3 T4's `CurrencyCode` catalog layers the business meaning — which codes actually exist — on top of it.
  ///
  /// `check()` rather than the shorter `withLength(min: 3, max: 3)`, which is what this column was written as first. `withLength` compiles to a Dart-side
  /// validator and nothing else: the column reached the schema dump as a bare `TEXT NOT NULL`, so it would have held for a companion insert and evaporated
  /// for a raw upsert or a migration. `check()` is written into the `CREATE TABLE` instead, which also carries it into the fixtures W9 migrates against.
  /// Both paths are asserted in `test/features/accounts/data/tables/accounts_table_test.dart` — the second test is there precisely to fail if someone
  /// "simplifies" this back.
  TextColumn get currencyCode => text().check(currencyCode.length.equals(3))();

  /// Minor units, `int` — golden rule 2. 1.500.000 ₫ is `1500000`; $12.34 is `1234`. There is no `double` anywhere on the path from here to the UI.
  ///
  /// The *opening* balance only. The current balance is never a column: §6 forbids a stored derived value without a recompute strategy, and §12.8 names it
  /// an anti-pattern outright. It is `initial_balance + SUM(transactions)` over an index, measured at W8.
  IntColumn get initialBalance => integer()();

  /// Archived ≠ deleted. An archived account disappears from pickers but keeps its history and keeps syncing; [deletedAt] is the tombstone.
  ///
  /// `boolean()` rather than `integer()`: the storage is the same `INTEGER` the blueprint specifies, drift adds `CHECK (is_archived IN (0, 1))` for free,
  /// and the Dart side gets a `bool` instead of an `int` that a caller could compare against 2.
  BoolColumn get isArchived => boolean()();

  /// Epoch millis, UTC — never an ISO string (§6), never `DateTime.now()` (§8 wants a fake clock, `GPClock` provides one).
  IntColumn get createdAt => integer()();

  /// Epoch millis, UTC. Half of the pull cursor at W12 T2, so it must move on every write the server should learn about.
  IntColumn get updatedAt => integer()();

  /// Optimistic-concurrency token (§7). Starts at 1 on create and is set from the server's response, never incremented hopefully on the client.
  IntColumn get version => integer()();

  /// Soft-delete tombstone (golden rule 5): epoch millis when deleted, null while alive. Every local query filters `deleted_at IS NULL` — audited across
  /// all DAOs at W12 T3.
  ///
  /// Not indexed. At transaction scale a partial index earns its keep; a user has a handful of accounts, and an index nothing needs is still an index every
  /// write maintains.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// Stated, not derived — a Dart rename must not become a schema change behind the author's back. Same reasoning as `settings`.
  @override
  String get tableName => 'accounts';
}
