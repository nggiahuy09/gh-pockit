# ADR 0029 — Each migration step commits with its own version

## Status

Accepted — 2026-11-05 (W10 T2, started early). No schema change; `schemaVersion` stays 5.

## Context

Drift 2.31 runs a migration with no transaction around it. `DelegatedDatabase._runMigrations` (`engines.dart`) does three things in
order:

1. It calls `onCreate` or `onUpgrade`. Each statement inside commits on its own.
2. It calls `beforeOpen`.
3. Only then does it write `PRAGMA user_version`.

So a migration that stops part-way leaves the steps it ran on disk while the version still says "before". The stop can be a kill, a crash
or a failing statement. The next launch runs the same steps again.

- `createTable` emits `CREATE TABLE IF NOT EXISTS`, so a table that is already there is skipped.
- `createIndex` emits the generated `CREATE INDEX …` with no `IF NOT EXISTS`, so an index that is already there fails.

The app then fails on every launch, with no way out short of reinstalling. A test reproduced it on the code before this ADR. A v3
database was killed part-way through the v4 step. On the next open it threw
`index transactions_owner_id_occurred_at_id already exists`, and it threw the same on every open after that.

The same hole has two more ways in:

- **A first launch.** `onCreate` runs `createAll` with no transaction either. A kill there leaves some tables and `user_version = 0`. The
  next launch runs `createAll` again and fails on its first index.
- **After a migration that finished.** If every statement ran but the app dies before step 3, the version is lost. The cause can be in
  `beforeOpen` or between the two calls.

## Decision

**Every step runs in its own transaction, and that transaction writes the version the step reaches.**

```dart
onCreate: (m) => _commitAt(schemaVersion, m.createAll),
onUpgrade: (m, from, to) async {
  for (var version = from + 1; version <= to; version++) {
    await _commitAt(version, () => _upgradeTo(version, m));
  }
},

Future<void> _commitAt(int version, Future<void> Function() step) => transaction(() async {
  await step();
  await customStatement('PRAGMA user_version = $version');
});
```

- **DDL in SQLite is transactional.** `CREATE TABLE`, `CREATE INDEX`, `DROP INDEX` and the `user_version` in the file header are all
  rolled back together. After a kill, SQLite rolls back the hot journal on the next open. After a thrown error, drift rolls back
  explicitly. Both leave the same state.
- **The version is written inside the transaction.** The schema and the number that names it reach disk together, so step 3 above has
  nothing left to lose. Drift still writes the version afterwards, and that second write is a no-op.
- **The steps are a loop over versions.** Before, they were `if (from < N)` blocks. A device several releases behind still runs every
  step it missed, in order, and each step is one unit that can succeed or roll back alone. A version with no step throws a
  `StateError`, which rolls the step back. The old blocks wrote the new version over a schema that never got the step.
- The guard `to >= 5` disappears. The loop stops at `to`, so a migration test that stops at v4 never runs the v5 step.
  `_v4AccountIndex` stays; it is T3's to remove.

### One transaction per step, not one around the whole upgrade

Both are safe. The difference is where a device is left when step 4 of 1 → 5 fails:

|                       | Per step (chosen)                                                                                                     | Whole upgrade                                                     |
| --------------------- | --------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| Left at               | v3, with v2 and v3 committed                                                                                          | v1                                                                |
| Next launch redoes    | step 4 onward                                                                                                         | every step                                                        |
| What the test can see | `user_version = 3` proves the version went in with the steps, because the failed open never reached drift's own write | only "nothing changed", which a missing version write also passes |

Per step also matches drift's `stepByStep`, which T3 adopts: its generated `migrationSteps` hands out one function per version.

## How it is tested

`migration_test.dart`, group _a migration that dies part-way_. The fault is a real SQLite error, not a hook in production code. Before
opening, the test plants a `fault` table and gives an index on it the name of the last index the v4 step creates. The step then fails
after everything before it ran, which is the state a kill there leaves. Dropping `fault` stands for the next launch, where whatever
killed the app is gone.

- A v3 database that fails in the v4 step stays at v3. No `transactions` table or index is left, and its v3 rows are untouched.
- The next launch runs the v4 step again in full. The database then validates against the v5 dump, rows intact. Before this ADR, this test
  failed with the "already exists" error above.
- A v1 database that fails in the v4 step ends at v3, holding exactly the v2 and v3 tables and indexes. It then reaches v5.
- A first launch that fails in `createAll` leaves an empty file at version 0. The next launch creates the full v5 schema.

All four tests failed on the code before this ADR.

## Consequences

Positive:

- The file always holds the schema its `user_version` names. A step either happened or did not.
- A migration that fails for a passing reason, such as a kill, low memory or the OS ending a long launch, recovers on the next launch
  by itself.
- Data migrations in later steps get the same guarantee for free: a step that rewrites rows does it all or not at all.

Negative:

- A step's work is held until it commits. The v5 step rebuilds two indexes over every transaction, and a kill during it throws the rebuild
  away and pays it again. T5 measures that rebuild at 50k.
- A step cannot use a statement that refuses to run in a transaction. `VACUUM` fails. `PRAGMA foreign_keys` does nothing at all, so a
  future step that rebuilds a table with foreign keys off must turn them off before `_commitAt`, not inside it.
- A step that fails every time, which is a bug, now leaves the device on the old version and failing on every launch. That is still a
  crash loop, but a consistent one: a release that fixes the step finds the database exactly where the step expects it. What the user
  sees meanwhile is not decided here. The bootstrap has no screen for a failed open yet.

## Alternatives rejected

**`IF NOT EXISTS` on every `CREATE INDEX`.** It makes a re-run pass, but only for steps that create things. A step that drops and
rebuilds an index (v5), or rewrites rows, is not idempotent. The flag would also hide an index of the right name with the wrong shape.
The statements are generated, too, so they are not ours to edit.

**Catching the failure and recreating the database.** It breaks golden rule 7, never wipe on a schema change. Every unsynced row would be
lost, and before P4 that is every row there is.
