# ADR 0035 — The delta pull's indexes are `(owner_id, updated_at, id)`, on every synced table

## Status

Accepted — 2026-11-09 (W11 T5, started early). The roadmap row asked for `(owner_id, updated_at)`. This ADR adds `id`, and puts the
index on all three tables. No local schema change.

## Context

- The pull (W15) pages each table by a composite cursor, `(updated_at, id)` (system-design §6.2): ordered by `updated_at, id`, starting
  after the cursor, `limit n`.
- It runs as `authenticated`, and RLS adds `owner_id = (select auth.uid())` (ADR-0034).
- The only index each table had was its primary key, `(owner_id, id)`. It finds an owner's rows, but not in cursor order.
- Locally, every list index ends in `id`, so that the `ORDER BY` needs no sort (ADR-0009).

## Decision

1. **One index per synced table, `(owner_id, updated_at, id)`**, named `<table>_owner_id_updated_at_id`.
   - With `id` in the index, `ROW(updated_at, id) > ROW(cursor)` is a single index condition, next to the owner's equality, and the scan
     returns rows already in cursor order.
   - Without `id`, the index covers only `updated_at >= cursor`. Every row sharing the cursor's timestamp is then read and filtered, and an
     incremental sort orders the rest. Seeded categories share one timestamp, and a batch write can too.
2. **On accounts and categories too.** They are pulled the same way. An owner has tens of them, and they are rarely written, so the index
   costs little to keep.
3. **The query shape is pinned now, ahead of W15.** The test runs the exact pull query, as `authenticated`, through RLS. W15's server
   function has to keep that shape, or the test that guards the index stops describing the query.
4. **Plain `CREATE INDEX` in a migration,** because the tables are empty. Once they hold data, a new index is built `CONCURRENTLY`, which
   cannot run inside a migration's transaction.

## Measured

Host tier: the local Postgres 17.11 in OrbStack on an M1. 500k transactions, 50k for each of ten owners in one table, with 24 months of
history. Each figure is the third, warm run, from `supabase/benchmarks/delta_pull.sql`, which rolls everything back. The two-column
column swaps the index in a separate run over freshly generated data; two such runs gave 0.095 and 0.103 ms for the first page.

| Pull for one owner (50k rows)          | `(owner_id, updated_at, id)` | `(owner_id, updated_at)` | Primary key only                      |
| -------------------------------------- | ---------------------------- | ------------------------ | ------------------------------------- |
| First page, 200 rows, empty cursor     | 0.063 ms, 204 buffers        | 0.10 ms, 204 buffers     | 10.5 ms, 1266 buffers                 |
| Incremental, 10 changes since a cursor | 0.012 ms, 13 buffers         | 0.016 ms, 14 buffers     | 5.2 ms, 1266 buffers, 49,990 filtered |

- **Primary key only:** a bitmap scan on `(owner_id, id)` reads all 50k of the owner's rows, then sorts them. The cost grows with the
  owner's whole history.
- **With the index:** the cost grows with the page. RLS's `owner_id = (InitPlan 1).col1` lands in the `Index Cond`.
- **The two-column variant** is close while timestamps are distinct. Its gap is the ties described in decision 1.

## Consequences

Positive:

- A pull reads only the rows it returns, whatever the owner's history.
- The query W15 must run is written down and tested before W15 starts.

Negative:

- Every write to a synced table maintains one more index. A transaction row carries a 16-byte owner, an 8-byte timestamp and a 16-byte id
  in it.
- The pull's shape is fixed by a test before the function that runs it exists. Changing the cursor means changing this index and its test
  together.

## Open, for T6 and W15

_Settled 2026-11-09 by ADR-0036: a per-owner lock and "newest + 1" stamp `updated_at` in commit order._

A timestamp cursor misses rows that commit out of timestamp order. Two of one owner's devices push at once:

1. Push 1 stamps its row at t=1 and commits late.
2. Push 2 stamps t=2 and commits first.
3. A pull in between advances its cursor past t=2.
4. Push 1's row lands behind the cursor and is never pulled.

T6, which sets `updated_at` on the server, has to make it increase in commit order for each owner. One way: a per-owner lock, then
`greatest(now, the owner's newest + 1)`. That lookup is what this index serves.

## How it is tested

`supabase/tests/database/delta_pull.test.sql`, 4 assertions:

- **Definitions:** the three index definitions, exactly.
- **Plans:** for each table, the pull query as `authenticated` through RLS, with sequential scans, bitmap scans and sorts priced out. Its
  plan must be one index scan on that table's index, with the owner and the row comparison in the `Index Cond`, and no sort. On failure,
  the test prints the plan.

Checked that the test bites: with `transactions` indexed on `(owner_id, updated_at)`, the plan shows `updated_at >= 0`, a `Filter` and an
`Incremental Sort`. With no index on `accounts`, the plan shows a scan on the primary key plus a `Sort`. Three assertions fail. With the
migration restored, all 64 across the suite pass.
