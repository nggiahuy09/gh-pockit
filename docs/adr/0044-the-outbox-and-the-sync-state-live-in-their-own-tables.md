# ADR 0044 — The outbox and the sync state live in their own tables

## Status

Accepted — 2026-11-25 (W13 T2, started early). Schema v6. This covers the two tables' shapes only: what a mutation means, how one is
written next to its entity, and what the engine does with it are T3–T5 and the Flex ADR (_Use outbox for local mutations_), which will
amend or extend this one.

**v6 stays open until the W13 PR.** Nothing at v6 has shipped, so T3–T5 may still change these tables inside v6, re-dumping
`drift_schema_v6.json` and regenerating the steps and fixtures. Once the PR merges, v6 is frozen like every earlier version (CLAUDE.md §6).

Amended 2026-11-25 (W13 T3): the vocabulary the table leaves unchecked, and `baseVersion` settled. See _Amended — T3_ at the end.

Amended 2026-11-25 (W13 T4): v6 gains a partial unique index, and the queue's contract is fixed. See _Amended — T4_.

## Context

- Golden rule 3 puts the entity write and its mutation in one transaction, so the outbox lives in the same database (ADR-0001).
- Blueprint §20 lists both tables. Most of its shape is kept. Three points are decided here, because SQLite cannot `ALTER` a constraint:
  changing one later is a table rebuild (as in ADR-0009).
- CLAUDE.md §6 requires `sync_mutations(status, next_attempt_at)`. ADR-0009 creates an index with the first query that reads it. That
  query is T4's `getReadyMutations`, in the same PR.
- `settings` survives a sign-out (ADR-0042, decision D). A pull cursor must not survive one: the server filters every pull by owner
  (ADR-0034), so account B pulling from account A's cursor would skip every row of B's older than that cursor.

## Decision

1. **`sync_mutations`** has blueprint §20's columns: `id`, `entity_type`, `entity_id`, `operation`, `payload_json`, `idempotency_key`,
   `created_at`, `attempt_count`, `next_attempt_at`, `status` and `last_error_code`. Only `last_error_code` is nullable.
2. **`next_attempt_at` is `NOT NULL`,** unlike the blueprint. Enqueue sets it to `created_at`.
   - "Ready to push" is then one range: `status = 'pending' AND next_attempt_at <= :now`.
   - With NULL meaning "now", every read needs an `OR next_attempt_at IS NULL` branch.
3. **`UNIQUE (idempotency_key)`.** A key minted twice would let the server's dedupe (system-design §6.4) apply one mutation and answer
   the other with the first one's result. That silently drops a write.
4. **`CHECK (attempt_count >= 0)`.** A negative count has no meaning for the backoff (blueprint §28).
5. **No vocabulary CHECK** on `entity_type`, `operation` or `status`. As in ADR-0009 §3, a new value would otherwise be a table rebuild.
   The mapper (T3) refuses an unknown value on read.
6. **No foreign key on `entity_id`.** It points into whichever table `entity_type` names.
7. **No `owner_id`.** The device has one owner (ADR-0040), so the outbox is that owner's. Two writes already change a row's owner without
   going through the outbox, and both are T5's to handle:
   - the claim moves `'local'` rows to the uid;
   - the claim drops a never-synced duplicate seed.
8. **No sync columns, and hard deletes.** It is an internal table. A mutation is deleted only after the server's answer (golden rules 5 and 6).
9. **`last_error_code` holds a code only,** never a server message: a message can echo the payload back (golden rule 9).
10. **Index `sync_mutations_status_next_attempt_at (status, next_attempt_at)`,** created now because the roadmap places it in T2.
    - Its shape is pinned before its query: `sync_mutations_table_test.dart` asserts that the ready range is one `SEARCH` on it.
    - T4's query must keep that plan.
    - If T4 needs to order by `created_at, id`, it widens the index inside v6. _(T4: not needed, see Amended — T4, item 7.)_
11. **`sync_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)`,** as in the blueprint. It is separate from `settings` because the two
    have different lifetimes. No key is written yet: the cursor arrives with W15, and the device id with W14.
12. **The v5 → v6 step creates both tables and the index, and backfills nothing.** Rows that are `pending` from before v6 get their
    mutations at T5 (ADR-0009). Nothing in the step rewrites rows, so there is no 50k cost to measure.

## Consequences

Positive:

- The outbox's three hard constraints (unique key, non-negative count, a time on every row) are in the `CREATE TABLE`, before any row
  exists to violate them.
- The ready query is a single index range. It is asserted by the plan, not by timing.
- The sync engine's state has a home with its own lifetime, so `settings` keeps meaning "device preferences".

Negative:

- **`UNIQUE` adds a second index** (`sqlite_autoindex_sync_mutations_2`) to every enqueue. The outbox holds what has not synced yet,
  usually a handful of rows, so the write cost is small.
- **`payload_json` holds amounts and notes in plain text,** just as the entity tables do. Diagnostics must never show it (W17 T3).
- **Open, for later tasks:**
  - ~~Is `baseVersion` a column, or part of the payload?~~ Part of the payload: settled at T3, see _Amended — T3_.
  - What does a sign-out clear in `sync_metadata`? The cursor, surely; the device id, perhaps not. Decided with the first key that
    lands there (W14 / W15). Until then, `wipeOwnerRows` (ADR-0042) does not touch the table, which stays empty.

## How it is validated

- `sync_mutations_table_test.dart` checks:
  - every column round-trips;
  - a duplicate idempotency key, a negative attempt count and a NULL `next_attempt_at` are each refused;
  - `EXPLAIN QUERY PLAN` of the ready range shows exactly one `SEARCH ... USING INDEX sync_mutations_status_next_attempt_at`.
- `sync_metadata_table_test.dart`: one value per key, and the last write wins.
- `migration_test.dart` checks:
  - v5 → v6 matches a fresh v6;
  - v5 rows (settings, account, transaction) come across column for column, and both new tables are empty;
  - the named index exists on the upgrade path;
  - v4, v3, v2 and v1 each walk to v6;
  - the v1 → v6 chain writes mutations and metadata at v6 through the typed fixture and reads them back unchanged. The app's
    `SyncMutationRow` decodes a retried mutation, payload with Vietnamese text and quotes included;
  - a file at v7 is refused untouched (ADR-0030, moved up one version).
- Mutation check: without `createIndex` in `from5To6`, 6 migration tests fail.

## Alternatives rejected

**Sync state in `settings`, under a `sync.` prefix.** That means one table less. Rejected: sign-out keeps `settings` whole, so it would
have to start deleting by prefix. A table's lifetime is easier to see than a naming rule.

**Nullable `next_attempt_at` (blueprint §20).** Rejected by decision 2. Every reader would carry the `IS NULL` branch, and the NOT NULL
cannot be added later without a rebuild.

**`id` doubling as the idempotency key.** That would be one column and one index fewer. Rejected for now: T3 lists `idempotencyKey`
separately, and system-design §6.2 sends both. Coalescing (W13) may replace a pending mutation's payload while keeping its key, and that
reads better with a key that is not the row's identity. If T3 finds no use for two values, dropping the column inside v6 is cheap.

## Amended — T3 (2026-11-25)

The W13 plan was locked on 2026-11-25 (decisions A–E in ROADMAP, _Kế hoạch W13_). The Flex ADR will record A–D. T3 settles what the table's
text columns may hold, and decision E settles the open `baseVersion` question.

1. **The vocabulary.** It lives in `core/sync/` (`GP` prefix, §3), with every stored value written out rather than derived from the Dart
   name:
   - `GPSyncEntityType`: `account`, `category` and `transaction`;
   - `GPSyncOperation`: `create`, `update` and `delete`, with no `upsert`. The server treats an insert and an update differently: the
     columns a patch leaves out are refused once written (ADR-0036). A soft delete is `delete`, and a restore is `update` (ADR-0017);
   - `GPSyncMutationStatus`: `pending`, `processing`, `conflict` and `failed`. There is no `completed`, because an acknowledged mutation is
     deleted (golden rule 6).
2. **An unknown value is refused on read, never guessed.** `GPSyncMutationRowMapper.toDomain` returns `GPUnmappableSyncMutationRow` with a
   reason: unknown entity type, unknown operation, unknown status, or a payload that is not a JSON object. The reason names the check,
   never the value, because it goes to the log. What T4 does with such a row (skip it, or mark it `failed`) is T4's call.
3. **`baseVersion` is the payload's `version`, not a column.** The DAOs never write `version`, which is the server's (ADR-0036,
   `account_dao.dart` and its siblings), so a row's `version` stays the version the server last gave it until a push is acknowledged.
   The snapshot taken at enqueue (decision E) therefore carries the base the server checks, and a coalesced mutation keeps that same
   `version`.
4. **The folding rule is a pure function,** `GPSyncOperation.followedBy`: a chain that starts with `create` stays `create`, and any other
   takes the later operation. A `create` after an `update` or a `delete` throws: that row was created already, and an insert pushed for
   it would be refused on its primary key. `GPSyncMutation.coalescedWith` applies it, keeps the id, the key, `created_at` and `next_attempt_at`, and
   throws on a mutation that has been attempted. Such a mutation may already have reached the server under its key, so a new payload
   under that key would be answered with the old result.
5. **`toLog()` holds only ids, type, operation, status, attempt count and the error code.** It never holds the payload or the key
   (golden rule 9).
6. **An attempt is counted when the mutation is sent, not when it fails.** `sending()` sets `processing` and `attempt_count + 1` before
   the request leaves, so T4 writes that before the push and `scheduleRetry` does not count again. Without it, a kill mid-push followed by
   the launch reset (`processing` → `pending`) leaves `pending` with 0 attempts. That looks never sent, and coalescing would then put a
   new payload under a key the server may already have answered.
7. **A payload is one flat row of JSON scalars:** strings, integers, booleans and nulls. The constructor throws on anything else, naming
   the column and its type, never the value. `jsonEncode` then cannot fail inside the write's transaction, `Map.unmodifiable` really
   freezes it (nothing nested stays shared with the caller), and a stored payload with a fraction or a nested value reads as malformed.
8. **Times are whole milliseconds in UTC,** truncated on construction, as the table stores them. A mutation built from the system clock
   is then equal to itself after a write and a read.

Validated by `sync_vocabulary_test.dart` (the stored values pinned literally, the round trip, unknown values, the seven folding pairs),
`sync_mutation_test.dart` (queued state, UTC, an unmodifiable payload, coalescing and its refusal, the log, equality) and
`sync_mutation_mapper_test.dart` (a round trip through a real table, JSON past 32 bits and with Vietnamese text and quotes, six
unreadable rows). After the code review the same day, items 4, 6, 7 and 8 were added, with 14 tests. Without the `+ 1` in `sending()`
and the payload check, 8 tests fail. Two mutation checks were run on the first version. With the rule changed to "always the later operation", or with the attempted-mutation
guard removed, 4 tests fail.

## Amended — T4 (2026-11-25)

`GPSyncQueueRepository` (interface) and `GPDriftSyncQueueRepository` live in `core/sync/`. The queue is registered in DI as a singleton
on the app database.

1. **v6 gains `sync_mutations_unattempted_entity`:** `UNIQUE (entity_type, entity_id) WHERE status = 'pending' AND attempt_count = 0`.
   v6 had not shipped, so the dump, the steps and the fixtures were regenerated.
   - The index makes "at most one unsent mutation per entity" part of the schema. Enqueue folds a later write into that mutation, so a
     second one can only come from a bug, and the insert then fails along with the entity write.
   - It also serves the lookup that folding needs. That lookup writes the index's `WHERE` with literals
     (`GPDriftSyncQueueRepository.unattemptedSql`), because SQLite applies a partial index only when it can prove the condition, and a
     bound value does not prove it.
2. **Every method throws, and none returns a `GPResult`.** `enqueue` runs inside the entity write's transaction as a savepoint. A failure
   swallowed there would commit the entity without its mutation, which is what golden rule 3 forbids. A refused fold (a `create` after an
   `update`) rolls the caller's write back too.
3. **`markSending(id)` re-reads the row** and writes `sending()` in one transaction, then returns that copy. A write can fold into the
   mutation between `getReadyMutations` and the send, and sending the earlier copy would have the server apply the old payload. The
   following `complete` would then delete the new one.
4. **`scheduleRetry`, `markConflict` and `markFailed` touch only a mutation in flight** (`processing`). An answer for anything else is
   ignored. `scheduleRetry` does not count the attempt again.
5. **`resetOrphans` puts `processing` back to `pending` and keeps the count**, so an orphan is never folded into (Amended — T3, item 6).
   It logs the number only.
6. **A row this build cannot read is marked `failed`** with `last_error_code = 'unreadable_row'`, and the id and the reason are logged.
   That leaves it visible to Diagnostics, keeps it out of every push, and moves it out of the partial index so a new write can queue.
7. **The ready order is `created_at, id`,** so a parent written before its child is pushed first. The status index serves the range,
   and SQLite sorts the due rows afterwards (`USE TEMP B-TREE FOR ORDER BY`). That is a handful of rows, so decision 10's index stays as
   it is, unwidened.
8. **`countUnsyncedEntities` counts distinct entities**, whatever the state of their mutations: a failed or conflicted mutation is still
   a change the server lacks. T5 builds the sign-out count on it.

Open, for W14: a child can be due while its parent waits in backoff. The push would then send the transaction before its account, and
the server's foreign key refuses it. The engine has to decide whether to stop at the first failure or hold children back.

Validated by `drift_sync_queue_repository_test.dart` (25 tests: enqueue, folding, never folding into a sent or orphaned mutation, keeping
entities apart, commit and rollback with the caller, a refused fold rolling the caller back, an unreadable row set aside, both query plans,
the ready filter and order, `markSending` returning the folded payload, settling only in flight, retry timing, orphans, the count), the
table test (a second unsent mutation refused, and allowed beside a sent one), the migration test (both indexes on the upgrade path) and
`injector_test.dart`. With the in-flight guard removed, or with `scheduleRetry` counting again, 2 tests fail.
