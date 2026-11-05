# ADR 0027 — The two account indexes cover the balance query

## Status

Accepted — 2026-11-04 (W9 T6). Schema v5.

Amended 2026-11-05 by ADR-0029: the migration no longer needs the `to >= 5` guard or the hand-kept v4 index definitions. Each step
now runs on its own version's generated schema.

## Context

ADR-0019 computes every balance in one query. Each account runs two correlated subqueries:

- one over the transactions it is the source of;
- one over the transfers it receives.

Each subquery seeks the account's index and then reads the table row, because `type`, `amount_minor` and `deleted_at` are not in the
index. ADR-0019 left the covering index to W9: "whether that saves enough to pay for one more index on every write is W9's to measure."

W9 measured it on the host, in JIT, with the same harness throughout (ADR-0026):

| Balances, repository median |      1k |     10k |                    50k |
| --------------------------- | ------: | ------: | ---------------------: |
| v4 indexes                  | 0.50 ms | 2.84 ms | **26.8 ms** (p90 35.5) |

Five times the rows cost ten times the time. The 50k file is 27 MB against an 8 MB page cache, so the row reads stop hitting the cache.
Raising the cache to 64 MB took a probe from 19.2 ms to 12.9 ms. A covering index took it to 4.5 ms. The reads are the cost, and the cache
size only hides part of them.

Every transaction write re-runs this query (ADR-0019), on Home and on Accounts. It is the slowest query in the app that grows with the
history.

## Decision

**Widen the two existing account indexes instead of adding two new ones.** Both keep their names and their key prefix, and gain the three
columns the balance reads:

- `transactions_account_id_occurred_at_id` becomes `(account_id, occurred_at, id, type, amount_minor, deleted_at)`;
- `transactions_destination_account_id_occurred_at_id` becomes `(destination_account_id, occurred_at, id, type, amount_minor, deleted_at)`.

The balance plan becomes `SEARCH t USING COVERING INDEX …` on both sides, so no row of the table is read. A probe compared the two options
at 50k:

| Option                                                              | Balances (SQL) | DB file | One insert |
| ------------------------------------------------------------------- | -------------: | ------: | ---------: |
| v4                                                                  |        22.0 ms | 26.9 MB |    0.94 ms |
| A — two more indexes `(account_id, deleted_at, type, amount_minor)` |         4.0 ms | 31.3 MB |    0.73 ms |
| B — widen the two account indexes                                   |         4.9 ms | 28.1 MB |    0.60 ms |

B is within a millisecond of A, uses 3 MB less, and adds no index to maintain on a write. It also keeps the `(account_id, occurred_at, id)`
prefix that a `UNION ALL` account filter (W4 T5) would seek. The single-insert times are within noise for all three: a write is dominated
by the round trip to the database isolate, not by the index.

**Migration v4 → v5:** drop both indexes and create them again. SQLite cannot alter an index, and the rebuild reads the rows already
there.

- The v4 step now creates the v4 shape of the two indexes, so a migration that stops at 4 still leaves the v4 schema.
- The v5 step runs only when `to >= 5`. `to` is lower only in a migration test.

`migration_test.dart` runs against the committed v4 and v5 dumps in `drift_schemas/`. It carries v4 rows across, checks that the balances
read the same, and pins the covering plan.

## Consequences

Positive:

- Balances at 50k went from 26.8 ms to 5.0 ms (repository median), and p90 from 35.5 ms to 5.4 ms. Seeding 50k rows stayed at about
  990 ms, so the write cost did not move.

Negative:

- Each account index entry is wider, by a short text, an integer and a null. The file grows by about 1.2 MB at 50k.
- On a device that already holds data, the first launch after the upgrade rebuilds two indexes over every transaction. That is a one-off
  cost, paid once.
- The index names list their key columns only. The carried columns are in `transactions_table.dart` and in this ADR.

## Alternatives rejected

**Two narrow covering indexes (option A).** They are slightly faster, but every write maintains two more indexes, and the file grows 4 MB
at 50k for a gain of under a millisecond.

**A larger page cache.** It brings no change to the schema, but it only halves the cost, at 64 MB of memory, and the cost grows again with
the history.

**A stored balance column.** It is an anti-pattern without a recompute strategy (CLAUDE.md §12). The indexed aggregate is now fast enough
that one is not needed.
