# ADR 0009 — Transactions: one row per transfer, positive amounts, integrity in the schema

## Status

Accepted — 2026-09-27, before W4. Decided up front because most of it is
columns and constraints, and SQLite cannot `ALTER` a constraint: changing one
later is a table rebuild. Implemented by W4 T2 (`TransactionEntity`) and W4 T3
(the table).

## Context

`transactions` is the table every number in the app is computed from: balances
(W6 T6), monthly summaries and category breakdowns (W7), budgets (W24). The
`accounts` and `categories` slices each had one real modelling question. This
table has several, and they interact:

1. Is a transfer one row or two?
2. Does an amount carry a sign?
3. Which invariants live in the schema, and which only in the domain?
4. Foreign keys, now that `PRAGMA foreign_keys = ON` has been set since W2?
5. What does `sync_status` mean before a sync engine exists?
6. Is `occurred_at` an instant or a calendar date?
7. Which indexes exist on day one?

A constraint SQLite has accepted cannot be added or dropped with `ALTER TABLE`.
drift's `alterTable` rebuilds the table instead — a migration, with a fixture
test, for every such change. So these are decided before the table is written
rather than discovered after it has data.

## Decision

**1. A transfer is one row.** `type = 'transfer'`, `account_id` is the source
and `destination_account_id` the destination (blueprint §17 option A,
`docs/system-design.md` §Transfer):

```text
balance(A) = initial_balance
           + Σ amount_minor  WHERE type = 'income'   AND account_id = A
           - Σ amount_minor  WHERE type = 'expense'  AND account_id = A
           - Σ amount_minor  WHERE type = 'transfer' AND account_id = A
           + Σ amount_minor  WHERE type = 'transfer' AND destination_account_id = A
```

A transfer cannot be half-synced, half-edited or half-deleted, because there is
no second half.

**2. `amount_minor` is a positive magnitude, and `type` gives the direction.**
A transfer is money leaving one account and arriving in another in a single
row, so no sign is right for both sides: a signed amount would be correct for
two types out of three. Zero is refused — an entry that moves nothing is a
typo, not a transaction. A refund is recorded as income; netting it against an
expense category waits until budgets (W24) ask for it.

**3. The schema holds what makes a row uninterpretable; the domain holds what
the user is told.** The line `accounts.currency_code` already draws. In the
`CREATE TABLE`:

- `CHECK (amount_minor > 0)` and `CHECK (LENGTH(currency_code) = 3)` (ADR-0007);
- `CHECK ((type = 'transfer') = (destination_account_id IS NOT NULL))` — a
  transfer with no destination, or an expense with one, has no place in the
  balance formula;
- `CHECK (destination_account_id <> account_id)` — NULL passes, which is what a
  non-transfer needs;
- `CHECK (type <> 'transfer' OR category_id IS NULL)` — a transfer belongs to no
  spending category, as `category_type.dart` already records.

`TransactionEntity` states the same rules again, with a `GPValidationCode` for
each one a user can trip, and normalises the two a form can only get wrong by
leaving stale state behind: a transfer's category and a non-transfer's
destination are dropped rather than refused.

**No `CHECK (type IN (...))` and no `CHECK (sync_status IN (...))`.** A
vocabulary check turns every new value into a table rebuild. The mapper refuses
an unknown value on read instead, as `AccountType.fromStorage` does for
`accounts.type`.

**4. Foreign keys, with no `ON DELETE`.** `account_id` and
`destination_account_id` reference `accounts(id)`; `category_id` references
`categories(id)`. Nothing here is ever hard-deleted (golden rule 5), so there is
no delete action to choose. What a foreign key cannot see — whose parent it is,
and whether the parent is soft-deleted — is ADR-0010's.

_Settled at W4 T3:_ they are checked immediately, not
`DEFERRABLE INITIALLY DEFERRED`. Deferral would let one pull page apply children
before parents, but not across pages, which still have to arrive parents first;
and it moves the failure from the statement that caused it to the `COMMIT`, where
nothing says which row it was. Deferral is part of the constraint, so this is the
one foreign-key property that cannot change later without a rebuild.

**5. `sync_status` is `TEXT NOT NULL`, no default, two values.** `pending`: a
local write the server has not acknowledged. `synced`: the server has this
version. Every local write — insert, update, soft delete — sets `pending`; only
the sync engine writes `synced`, from W13. It stays off `TransactionEntity`
until the badge of W12 flex needs it.

**6. `occurred_at` is an instant**, epoch millis UTC like every timestamp here
(§6). A day or a month is computed in the device's current zone when it is
shown, and a range query takes instants that presentation computed from local
dates, half-open `[from, to)` (ADR-0011). This is what blueprint §Date/time
means by "instant + local display rules".

**7. An index is created in the change that adds the first query reading it.**
W4 T3 creates the four that the list query and its filters read — owner,
account, destination account and category — each followed by `occurred_at` and
`id`, so `ORDER BY occurred_at DESC, id DESC LIMIT n` is read straight off the
index by a backward scan (asserted with `EXPLAIN QUERY PLAN` in the table test).
`(sync_status)` waits for the P4 query that filters on it, `(updated_at)` for a
local query that needs one, if one ever does. W7 T2 becomes an
`EXPLAIN QUERY PLAN` audit of the new aggregates instead of a bulk add.
`CLAUDE.md` §6 lists the same indexes and now says when each one lands; it also
gained `destination_account_id`, which it lacked and the balance needs.

_Settled at W4 T3:_ the four are not partial (`WHERE deleted_at IS NULL`), though
every list query filters on exactly that. SQLite only picks a partial index when
the query repeats its condition, so a forgotten filter becomes a silent full
scan, and tombstones are rare in a personal ledger. Changing an index is a drop
and a create, not a rebuild, so this waits for W8's numbers. The same test showed
what the indexes cannot do: an account's history on **either** side of a
transfer (`account_id = ? OR destination_account_id = ?`) is a multi-index OR
followed by a sort of every row that matched — W4 T5's to solve.

**8. `receipt_id` is not in v4.** W9 T3 adds it with a real `ADD COLUMN` on a
table that already holds data — the migration W9 is built around.

## Alternatives

**Two rows per transfer** (blueprint §17 option B, double-entry-inspired). Every
balance becomes one `SUM`, and an account's history one `WHERE account_id = ?`.
Rejected: the pair has to be linked by a `transfer_id` and created, edited and
deleted together, and it syncs as two mutations — one can land while the other
conflicts, which is the half-transfer this model exists to rule out. The
blueprint itself files option B as a stretch goal.

**Signed amounts.** `SUM(amount_minor)` without a `CASE` for income and expense.
Rejected with decision 1: a single transfer row has no correct sign. Signed
amounts only work with two rows per transfer.

**No foreign keys, integrity in the repository only.** The P4 pull could apply
rows in any order. Rejected: a dangling `account_id` is otherwise noticed only
when a `JOIN` quietly returns fewer rows — the failure the comment on
`PRAGMA foreign_keys` in `database.dart` names.

**Vocabulary CHECKs.** They catch a typo at write time, but make a new value or
a rename a rebuild migration, and the mapper already refuses unknown values.

**Every index from `CLAUDE.md` §6 on day one.** Two of the five have no reader
before P4, and an index nothing reads is still maintained on every write — the
argument `accounts_table.dart` makes against a lone `(owner_id)` index.

**A local calendar date (`occurred_on`).** A transaction would stay on the day
it was entered even after the user travels. Rejected for V1: the blueprint chose
an instant, ordering inside a day needs the time anyway, and a date column
cannot answer "the last 24 hours".

## Consequences

Positive:

- A transfer is atomic in storage and in sync: one row, one mutation, one
  conflict.
- Every aggregate — W6, W7, W24 — sums positive integers filtered by `type`,
  which is the shape blueprint §37 and §38 already sketch.
- A row that breaks the transfer shape cannot be stored by any path: companion
  insert, raw SQL, migration or pull.

Negative:

- The balance has four terms and needs the `destination_account_id` index, and
  an account's history must match either side of a transfer (ADR-0011).
- A transfer between two currencies cannot be expressed until multi-currency
  (W37+); ADR-0010 refuses it.
- A refund cannot reduce an expense category's spending.
- Moving time zones re-buckets history by day.
- Foreign keys fix an order. The W14 pull applies parents before children —
  the check runs at COMMIT at the latest, `DEFERRABLE` or not, so a transaction
  whose account arrives on a later page fails its page. W11 T6's logout wipe
  deletes children first, or drops the file.
- `sync_status` duplicates the outbox's state. From W12 T5 the entity, its
  mutation and its status change in one transaction, and W13 deletes the
  mutation and sets `synced` in one. Every row written before W12 is `pending`
  with no mutation behind it, so W12 owes a backfill.
