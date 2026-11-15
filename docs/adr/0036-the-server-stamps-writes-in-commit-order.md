# ADR 0036 — The server stamps every synced write, in commit order per owner

## Status

Accepted — 2026-11-09 (W11 T6, started early). You chose a per-owner lock with "newest + 1" over a change counter and over leaving the
ordering to W15. Settles the question ADR-0035 left open. No local schema change.

## Context

- The pull cursor is `(updated_at, id)` (system-design §6.2, ADR-0035). A cursor only works if no row can later appear behind it.
- Until now, `updated_at` and `version` were whatever the client sent. A client's clock is not to be trusted (CLAUDE.md §7), and
  `version` is the server's by design: the local DAO never bumps it.
- Even a server clock is not enough. Two of one owner's devices push at once:
  1. Push 1 stamps its row at t=1 and is still open.
  2. Push 2 stamps t=2 and commits.
  3. A pull sees push 2's row and moves its cursor to t=2.
  4. Push 1 commits a row at t=1, behind the cursor. It is never pulled.
- ADR-0010 requires the server to refuse what the local domain refuses: changing an account's currency or a category's type.

## Decision

1. **A row trigger stamps every insert and update.**
   - `version` is 1 on insert and the old value + 1 on update.
   - `updated_at` is `greatest(server clock in ms, the owner's newest updated_at across all three tables + 1)`.
   - Whatever the client sent for either is overwritten. `created_at` keeps the client's value: an offline row was created when the user
     made it.
2. **One owner's writes commit one at a time.** The trigger takes `pg_advisory_xact_lock` on a hash of the owner id before reading the
   newest stamp, and holds it until commit.
   - A second push from the same owner waits, so its stamp is read after the first one has committed. Under READ COMMITTED, each statement
     in the trigger sees a fresh snapshot, so it sees that commit.
   - `updated_at` therefore rises in commit order, across all three tables, so W15 can pull them through one cursor or one per table.
   - Other owners never wait.
   - "Newest + 1" also keeps the order when the clock steps back, or when a burst lands within one millisecond.
   - The lookup is index-only on each delta-pull index (ADR-0035).
3. **A statement trigger takes the caller's lock before any row is locked.** An `UPDATE` locks its row before the row trigger fires. If
   only the row trigger took the owner lock, two multi-row transactions from one owner could each hold a row the other needs, and
   deadlock. A signed-in caller writes only their own rows (ADR-0034), so locking `auth.uid()` at the start of the statement removes that
   case. The row trigger's lock covers the service role, and is free when the statement trigger already holds it.
4. **Columns that never change after insert** are refused with `23514` and a named constraint (`<table>_<column>_fixed`):

   - all three tables: `id`, `owner_id`, `created_at`;
   - `accounts`: `currency_code` (ADR-0010);
   - `categories`: `type` (ADR-0010), plus `name_key` and `is_system`, a seeded row's identity (ADR-0002).

   The list is exactly what each local `toPatch` leaves out. The check uses `IS DISTINCT FROM`, so a whole row sent back with its fixed
   columns unchanged still passes. `owner_id` was already closed to signed-in users by RLS; the trigger also closes it to the service
   role, and it fires first, so a hand-over now fails with `23514` instead of `42501`.

5. **The functions live in a `private` schema.** The Data API serves `public` only, and `anon` and `authenticated` hold no usage on
   `private`. A trigger function is not permission-checked when it fires.

## Consequences

Positive:

- A pull can never pass a row that commits later, which the race test shows directly.
- The server, not a device clock, decides `updated_at`, and the server alone moves `version`.
- A second client cannot change what the domain treats as fixed.

Negative:

- One owner's concurrent writes queue behind each other. A push is a few rows, so the wait is one short transaction. Other owners are
  unaffected.
- Every write reads the owner's newest stamp in three tables: three index-only lookups.
- The ordering relies on READ COMMITTED, PostgREST's default. A function that runs at REPEATABLE READ would read a stale newest stamp.
- A burst of n writes within one millisecond stamps up to n ms ahead of the clock.
- After a push, a device's `updated_at` and `version` differ from what it sent. W14 takes `serverVersion` and `serverUpdatedAt` from the
  response, as system-design §6.2 already plans.
- W14's push should also take the owner lock at the start of a batch. The statement trigger does it for each statement anyway.

## How it is tested

`supabase/tests/database/server_stamps.test.sql`, 24 assertions:

- **Stamps:**
  - an insert gets version 1 and the server's clock, whatever the client sent, and keeps the client's `created_at`;
  - an update moves version by one and `updated_at` forward;
  - one owner's stamps rise strictly across all three tables, even within one millisecond;
  - with a stamp planted in 2100, standing in for a clock that stepped back, the next write lands at the planted value + 1;
  - another owner's newest stamp moves nothing;
  - a soft delete and its undo each bump the version, and the undo is stamped after the newest write.
- **Fixed columns:** eight refusals, plus the editable columns of each table still changing and a whole row sent back unchanged passing.
- **Locks:** a service-role write holds its owner's lock; a signed-in statement that matches no row still holds the caller's lock; the
  Data API roles cannot reach `private`.

`supabase/tests/concurrency/commit_order.sh` runs two real sessions, which pgTAP cannot. Push 1 stamps and stays open for five seconds.
Push 2 starts, and a pull runs in between. The script checks four things:

1. push 2 waits on the advisory lock;
2. the pull sees neither row;
3. the next pull from its cursor returns both rows, push 1's first;
4. push 2 is stamped after push 1.

CI runs it after the pgTAP suite.

Checked that the tests bite: with both locks removed, push 2 does not wait and the pull in between sees its row. The next pull from that
cursor then returns nothing, so push 1's row is lost, which is the race this ADR exists for. Two pgTAP lock assertions fail as well.
With the migration restored, all 88 pgTAP assertions and the four race checks pass.

## Alternatives rejected

**A per-owner change counter, `change_seq`, as the cursor.** Strict order in O(1), with no clock. It costs a new table, a server-only
column on each synced table, a cursor that departs from system-design, and a counter row for every user. It would also replace T5's
index.

**A plain clock stamp, and let W15 cope.** A pull that re-reads a trailing time window only works if no transaction stays open longer
than the window. The bug class would stay open until W15.

**One trigger per table with its columns named in the body.** It needs three copies of the same logic. Passing `TG_ARGV` and comparing
through `to_jsonb` keeps one function.
