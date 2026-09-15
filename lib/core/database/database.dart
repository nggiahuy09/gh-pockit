import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:ghpockit/core/database/tables/settings_table.dart';
import 'package:ghpockit/features/accounts/data/tables/accounts_table.dart';

part 'database.g.dart';

/// The one persistent store for domain data (ADR-0001).
///
/// Everything that survives a restart lives here — entities, local settings, and from P4 the `sync_mutations` outbox. One database is the whole reason
/// golden rule 3 can be a single `transaction {}` block instead of a two-phase commit between two stores that cannot agree on whether a write happened.
/// The exception is auth tokens, which belong in `flutter_secure_storage` because that is an OS-keystore concern rather than a data-modelling one.
///
/// Auth tokens aside, nothing else may open its own store. A second persistent store is a second thing that can be inconsistent after a crash.
@DriftDatabase(tables: [SettingsTable, AccountsTable])
class GPAppDatabase extends _$GPAppDatabase {
  GPAppDatabase() : super(_openConnection());

  /// Hermetic, in-memory, one per test — `NativeDatabase.memory()` from `package:drift/native.dart`.
  ///
  /// This is what CLAUDE.md §8 means by repository tests on an in-memory DB, and it is the reason those tests need no fixture files, no cleanup and no
  /// shared state between cases.
  // `e`, not `executor`: `use_super_parameters` wants the forward written as `super.x` and `matching_super_parameters` wants `x` to be the name drift
  // generated — which is `e`. Naming it anything else means silencing one of the two rules with an ignore comment, for a parameter that is positional
  // and therefore never written out at a call site anyway.
  GPAppDatabase.forTesting(super.e);

  /// v1 — `settings` only. v2 — adds `accounts` (W2 T3).
  ///
  /// Every bump costs a migration step below, a fixture test in `test/core/database/migration_test.dart`, and a fresh dump under `drift_schemas/` (§6,
  /// golden rule 7). v2 is the first time that bill is paid, and it was paid in full on purpose: golden rule 7 does allow wiping the database during
  /// Phase 0–1, and `settings` holds one language preference nobody would miss. Taking the exception would have meant W9 — an entire week built around
  /// migrating from a real earlier schema — starting with no earlier schema to migrate from, and the first migration this app ever runs being written
  /// against a user's data instead of against a fixture. So v1 survives as something to upgrade rather than something to delete.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),

    // Stepwise and cumulative: a device on v1 runs the v2 step, and a device installed fresh at v2 never comes here at all — `onCreate` above builds the
    // whole schema in one go. Both paths have to end at byte-identical schemas, which is precisely what `migrateAndValidate` asserts in the migration test
    // against the dumps in `drift_schemas/`. Written as `if (from < N)` rather than `switch (from)` so that a device that skipped a release still walks
    // every step it missed, in order.
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Table and index separately. `createTable` emits only the `CREATE TABLE`, so an index declared with `@TableIndex` would silently not exist on
        // upgraded devices while existing on fresh installs — the schema drift that the v2 fixture test is there to catch.
        await m.createTable(accountsTable);
        await m.createIndex(accountsOwnerIdIsArchived);
      }
    },
    beforeOpen: (details) async {
      // Off by default in SQLite, and re-set per connection — so it belongs here rather than in a one-time setup. Without it a foreign key is a comment:
      // `transactions.account_id` could point at an account that was never inserted, and nothing would say so until a JOIN quietly returned fewer rows.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// The production executor.
///
/// `shareAcrossIsolates: true` is not what puts the database off the UI isolate — `drift_flutter` already does that on its own, through
/// `NativeDatabase.createBackgroundConnection`. What the flag buys is that a *second* isolate opening the same name joins the same database instance
/// instead of opening a competing connection to the same file. That is exactly the shape of P4: `workmanager` runs background sync in its own isolate,
/// and without this the two connections race for the write lock and surface as "database is locked" — while stream queries in the UI never learn that
/// the background pull changed anything.
///
/// Decided now rather than in W7 because the flag is one line today and an API change later: the DAO surface that grows over W2–W6 has to be
/// isolate-safe from the start, since nothing that is not sendable across isolates can cross this boundary (ADR-0001, open question 2).
QueryExecutor _openConnection() => driftDatabase(
  name: 'pockit',
  native: const DriftNativeOptions(shareAcrossIsolates: true),
);
