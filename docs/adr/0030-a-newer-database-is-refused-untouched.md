# ADR 0030 — A database newer than the app is refused, untouched, behind a screen of its own

## Status

Accepted — 2026-11-05 (W10 T4, started early). You chose option A, refusing to open. No schema change.

## Context

A file can be at a higher `user_version` than the build that opens it:

- a TestFlight or beta build, followed by the older store build;
- an older APK sideloaded over a newer one;
- an OS backup taken on a phone with a newer release, restored onto a phone with an older one.

Drift treats that as an upgrade. `OpeningDetails.hadUpgrade` is true whenever the two versions differ, so it calls `onUpgrade(m, 6, 5)`.
The step loop (ADR-0029) does nothing when `from > to`. Drift then writes `user_version = 5` (`engines.dart`). Two things follow:

- **The old build works on a schema it does not know.** A column that v6 added as `NOT NULL` with no default fails every insert this build
  makes. A constraint that v6 added rejects rows this build thinks are valid.
- **The file is now labelled v5.** When the newer build is installed again, it runs step 5 → 6 over a schema that already has it.
  `CREATE TABLE IF NOT EXISTS` passes, but `CREATE INDEX` fails. ADR-0029 rolls that step back, but it can never pass.

The new test reproduced the first half: on the code before this ADR, the v6 file opened without a word.

ADR-0029 left a second question open: what the user sees when a step fails every time. Here, the bootstrap's first read was
`GPLocalization.init`, whose store swallows the error. The next read, `CategorySeeder`, threw before `runApp`. The result was a blank screen
with no way to tell what happened.

## Decision

**Refuse the file before any statement, and show a screen that says why.**

1. **In `onUpgrade`:** `if (from > to) throw GPDatabaseTooNewException(fileVersion: from, appVersion: to)`, ahead of the step loop. Drift
   writes the version only after the migration succeeds, so the file keeps `user_version = 6`, and nothing else in it changes. Android's
   `SQLiteOpenHelper.onDowngrade` makes the same call by default.
2. **The bootstrap opens the database first.** `GPAppDatabase.open()` runs the first query, and with it the migration, right after the
   error handlers are set and before anything else reads the database. On any failure, the bootstrap logs the error type and runs
   `GPDatabaseErrorApp` in place of `GPApp`. It catches `Object`, because a missing step throws drift's `ArgumentError`.
3. **The screen depends on nothing that just failed.** It uses no router, no `getIt` and no stored language. The language is the
   device's, because the stored one is inside the database that failed. It has the theme tokens and `GPEmptyState`, and shows one of two
   messages:
   - a newer file: update Pockit; nothing was changed or deleted;
   - anything else: the data is still on this device; close the app fully and open it again; update if it keeps happening. For a step
     that failed once, such as a kill, the relaunch is the fix (ADR-0029).

   It has no retry button. Drift keeps a migration error for the life of the connection, and the connection is shared with a background
   isolate (ADR-0001). Retrying in place would mean tearing both down, which a relaunch does cleanly.

## Consequences

Positive:

- The file is never relabelled. Installing the newer build again opens it as if nothing had happened.
- A database that will not open is explained instead of showing a blank screen. That closes ADR-0029's open question.
- `open()` adds no query at launch. `SELECT 1` is the query that opens the database, which the first screen would otherwise have done.

Negative:

- After a downgrade, the user cannot use the app until they update. This is on purpose: before sync (P4), this file is the only copy of
  their data.
- The screen offers no way out inside the app: no export, no reset, no "send report". Those wait for crash reporting.

## How it is tested

- `migration_test.dart`, group _a file from a newer release_. A v5 file gets a typed row, a `budgets` table and `user_version = 6`.
  Opening it twice fails both times with `fileVersion` 6 and `appVersion` 5. Afterwards `user_version` is still 6, every
  `sqlite_schema.sql` is unchanged, and the row is there. On the code before this ADR, the open succeeded.
- `database_error_app_test.dart`: both messages in both languages, with nothing registered in `getIt`.
- Not covered by a test: the six lines of bootstrap glue, which use the global `getIt` and `runApp`. They are checked by hand on a
  device instead (W10 T5).

## Alternatives rejected

**Option B — open the file when it is compatible.** Every version would declare the lowest version still able to read it, and every
future step would have to be classified as backward-compatible or not. The old build would still write under constraints it does not
know. Revisit in P4, once a server copy exists and a newer device can simply download again.

**Open, but leave `user_version` at 6.** The file keeps its label, but the old build still reads and writes a schema it does not know,
which is the first half of the problem.

**Recreate the database.** It breaks golden rule 7. Before P4, it deletes the only copy.
