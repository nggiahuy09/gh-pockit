# ADR 0044 — The outbox and the sync state live in their own tables

## Status

Accepted — 2026-11-25 (W13 T2, started early). Schema v6. This covers the two tables' shapes only: what a mutation means, how one is
written next to its entity, and what the engine does with it are T3–T5 and the Flex ADR (_Use outbox for local mutations_), which will
amend or extend this one.

**v6 stays open until the W13 PR.** Nothing at v6 has shipped, so T3–T5 may still change these tables inside v6, re-dumping
`drift_schema_v6.json` and regenerating the steps and fixtures. Once the PR merges, v6 is frozen like every earlier version (CLAUDE.md §6).

Amended 2026-11-25 (W13 T3): the vocabulary the table leaves unchecked, and `baseVersion` settled. See _Amended — T3_ at the end.

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
    - If T4 needs to order by `created_at, id`, it widens the index inside v6.
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
   takes the later operation. `GPSyncMutation.coalescedWith` applies it, keeps the id, the key, `created_at` and `next_attempt_at`, and
   throws on a mutation that has been attempted. Such a mutation may already have reached the server under its key, so a new payload
   under that key would be answered with the old result.
5. **`toLog()` holds only ids, type, operation, status, attempt count and the error code.** It never holds the payload or the key
   (golden rule 9).

Validated by `sync_vocabulary_test.dart` (the stored values pinned literally, the round trip, unknown values, the seven folding pairs),
`sync_mutation_test.dart` (queued state, UTC, an unmodifiable payload, coalescing and its refusal, the log, equality) and
`sync_mutation_mapper_test.dart` (a round trip through a real table, JSON past 32 bits and with Vietnamese text and quotes, six
unreadable rows). Two mutation checks were run. With the rule changed to "always the later operation", or with the attempted-mutation
guard removed, 4 tests fail.
