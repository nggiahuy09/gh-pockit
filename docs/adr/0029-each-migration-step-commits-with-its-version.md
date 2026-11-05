# ADR 0029 — Each migration step commits with its own version

## Status

Accepted — 2026-11-05 (W10 T2, started early). No schema change; `schemaVersion` stays 5.

Amended 2026-11-05 (W10 T3): the steps come from drift's generated `migrationSteps`, one schema per version. See the amendment at the end;
`_upgradeTo`, its `StateError` and `_v4AccountIndex` below are gone.

Amended 2026-11-05 by ADR-0030: what the user sees when a step fails every time is decided there.

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

## Amended 2026-11-05 (W10 T3) — each step sees its own version's schema

W9 T6 was the first time an entity that already shipped changed its definition. It showed the weak point of hand-written steps: an old step
reads the _current_ definition. The v4 step created the account indexes as declared now, in their v5 shape. The patch was right, but it was
a hand-kept copy (`_v4AccountIndex`, `_v4DestinationAccountIndex`), and every later redefinition would need another one.

**The steps now come from `lib/core/database/database.steps.dart`.** `drift_dev schema steps` generates it from the dumps in
`drift_schemas/`. It holds a `SchemaN` per version, each with that version's tables and indexes, and a `migrationSteps(from1To2: …,
from4To5: …)` that hands each step the schema of the version it reaches. The v4 step creates `Schema4`'s account indexes, which are the
v4 shape. The copies are gone.

```dart
onUpgrade: (m, from, to) async {
  for (var version = from; version < to; version++) {
    await _commitAt(version + 1, () => _upgradeFrom(version, this));
  }
},

final Future<int> Function(int from, GeneratedDatabase database) _upgradeFrom = migrationSteps(
  from3To4: (m, schema) async {
    await m.createTable(schema.transactions);
    await m.createIndex(schema.transactionsAccountIdOccurredAtId); // v4's shape
    // …
  },
  // …
);
```

- **`migrationSteps`, not `stepByStep()`.** `stepByStep()` wraps the same steps in `VersionedSchema.stepByStepHelper`, which loops over
  the whole chain inside `onUpgrade` with no transaction. That would undo the decision above. The loop and `_commitAt` stay, and call
  `migrationSteps` one version at a time.
- **A version with no step** now throws drift's own `ArgumentError` ("Unknown migration from N") instead of our `StateError`. It still
  throws inside `_commitAt`, so the step rolls back as before.
- **The two drift commands, not `make-migrations`.** `make-migrations` runs both, but it wants a `databases:` entry in `build.yaml` and
  its own layout: `drift_schemas/<db>/` and `test/drift/<db>/`. Using it would move five dumps and the generated test schemas, and rewrite
  §9, for nothing the two commands do not already give on the current layout.
- **Typed fixtures.** `schema generate --data-classes --companions` adds a `DatabaseAtVN` and companions to each `schema_vN.dart`. A row
  written into a v3 file goes through `v3.AccountsCompanion`, so the compiler checks it against v3's columns. Before, raw SQL was checked
  only when the test ran, and only by SQLite. In `migration_test.dart`, raw SQL is now left only for the planted fault and for reads of
  `sqlite_schema` and `user_version`.

Cost: `database.steps.dart` is 768 generated lines, committed, and must be regenerated after every new dump (CLAUDE.md §9). Its
`// dart format width=80` marker keeps `dart format .` from reflowing it to 180.
