# ADR 0031 — Synced entities are soft-deleted, and their tombstones are kept until sync can purge them

## Status

Accepted — 2026-11-05 (W10 Flex). This ADR writes down golden rule 5, which the code has followed since the first synced table (`accounts`,
W2 T3). It changes no code.

Blueprint §27 and `system-design.md` §12 call this ADR "0004". That number went to hand-written localization, so this is 0031.

## Context

Golden rule 5 says: _delete = soft delete (`deleted_at`) for every synced entity; hard delete only for internal tables_. Three tables sync:
`accounts` (v2), `categories` (v3) and `transactions` (v4). Each has had `deleted_at INTEGER NULL` since the version that created it, so
nothing ever needed a backfill.

The rule had no ADR. Four things P4 will lean on were only implicit in the DAOs: why a delete is not a `DELETE`, what a tombstone must keep,
how reads and writes treat one, and when one may finally go.

The case against a real `DELETE` is the pull. The pull reads a delta by cursor: the rows whose `updated_at` moved past it (CLAUDE.md §7).
A deleted row does not move. It just stops existing, which a delta cannot tell apart from "not changed". A second device would keep the row
forever. With a tombstone, the delete is an ordinary update, and the outbox and the delta carry it like any other.

Two decisions already lean on the row surviving its delete:

- ADR-0017 makes Undo a restore, which is just clearing `deleted_at`.
- ADR-0010 lets a list still name the account or category that a transaction was filed under after that parent is deleted.

## Decision

**A delete is an `UPDATE` that sets `deleted_at`, and the row stays.**

1. **What a delete writes.** `deleted_at = now` and `updated_at = now`, in one `UPDATE … WHERE id = ? AND deleted_at IS NULL`
   (`AccountDao.softDelete`, `CategoryDao.softDelete`, `TransactionDao.softDelete`).
   - `updated_at` must move, or the delta pull never sees the delete.
   - The `deleted_at IS NULL` guard makes a second delete write nothing.
   - A transaction is also stamped `sync_status = 'pending'`.
   - `version` is never written locally. It is the server's, as on every update.
   - A delete is not guarded by `version`, like the restore in ADR-0017. Which side wins against an edit made on another device is for
     P4's conflict policy to decide.
2. **What a tombstone keeps: every column, unchanged.**
   - The id stays taken, so a seeded category's deterministic id (ADR-0002 amendment) is not inserted again. `CategorySeeder` does not
     bring back a default category the user deleted.
   - The name stays, so a list can still name the parent (ADR-0010).
   - The amounts stay, so restoring is only clearing `deleted_at` (ADR-0017).
   - Unique indexes still count the tombstone (`categories_owner_id_name_key`).
3. **Reads.**
   - Every live read filters `deleted_at IS NULL` on the entity it returns.
   - A join to a parent does not filter the parent (ADR-0010).
   - Aggregates leave deleted transactions out, and fold a deleted category into "Uncategorised" (ADR-0010, ADR-0021).
   - The indexes stay full, not partial: SQLite would use a partial index only when a query repeats its condition
     (`transactions_table.dart`). The two account indexes carry `deleted_at` instead, so the balance query filters it without reading a
     table row (ADR-0027).
4. **Writes.**
   - Every update skips tombstones (`AND deleted_at IS NULL`). Editing a deleted row would move its `updated_at` and sync a change to
     something the user removed.
   - The one write a tombstone accepts is `TransactionDao.restore`, which only clears it.
   - Accounts and categories have no restore yet.
5. **Foreign keys have no `ON DELETE`.** Nothing synced is ever removed, so a reference never dangles. The W10 T6 test runs
   `PRAGMA foreign_key_check` after a file has walked v1 → v5.
6. **A hard delete is only for what never syncs.**
   - An outbox mutation, once the server has acknowledged it (golden rule 6, P4).
   - Logging out, which clears the whole local store (W12 T6). That is not the user deleting anything, and the server keeps the data, so
     it leaves no tombstones behind.
7. **Tombstones are kept for good, until P4 decides how to purge them.**
   - A purge is safe only once two things hold:
     - the server has the tombstone, meaning the mutation was acknowledged;
     - no device can still push an edit to that id, or the server refuses one for an id it has tombstoned.
   - Blueprint §27 sketches it as "older than 30 days and all sync guarantees satisfied → hard delete". The guarantees are P4's to define,
     and its ADR sets the purge.

## Consequences

Positive:

- A delete is an ordinary update, so the outbox, the pull and conflict detection need no second mechanism for it.
- Undo is cheap, and lists can still name a deleted parent.
- Foreign keys hold by construction.

Negative:

- **Every query has to remember `deleted_at IS NULL`.** Drift has no default row filter, so a forgotten clause shows deleted rows. The guard is
  review and the DAO tests: every read the DAOs have today has a test that keeps a tombstone out, or that lets one in on purpose.
- **Tombstones hold unique keys for good.** A deleted default category never comes back by seeding. That is intended, since the user
  deleted it, but it is permanent until a purge exists.
- **The file grows until the purge exists.** It is small in practice: the 50k benchmark set is about 2% tombstones, roughly 1,000 rows
  (ADR-0025).
- **A deleted row's content stays on the device.** A tombstone keeps the note and the amount, so the device keeps them after the delete,
  until a purge. That is the price of Undo and of the pull. A user may reasonably expect "delete" to mean gone, so the purge ADR must
  also decide whether a tombstone sheds its free text once Undo can no longer reach it.

## Alternatives rejected

**A `DELETE`, plus a log of deleted ids.** That is two mechanisms where one does. The log is a tombstone table that holds less, Undo
would have to re-insert the row from somewhere, and a list could no longer name a deleted parent.

**An `is_deleted` flag.** It loses _when_. The purge needs the age of the tombstone, and a deleted-at time is what the pull and the
conflict policy can order by.

**Moving deleted rows to an archive table.** Every reader that joins a parent would have to look in two places, and the foreign keys
would have to point at either.
