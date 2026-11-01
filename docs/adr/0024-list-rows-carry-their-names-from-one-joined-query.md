# ADR 0024 — A list row carries its category and account names, read in the same statement

## Status

Accepted — 2026-11-01 (W8 T5).

## Context

W8 T5 asked for an N+1 review of the transaction list: a row's category and account had to come in one query, with no extra query per row.
The review found no N+1 to remove, because the list did not show those names at all. Each row showed its note (or its type) and its amount.
The W7 canvas row (`CategoryKit.dc.html`) shows more:

- the category's disc;
- a subtitle that reads "category · account";
- for a transfer, a subtitle that reads "from → to";
- "Uncategorised", with an empty ring, for a missing or deleted category.

So T5 became: show those names, and read them without a query per row.

ADR-0010 has already settled what a soft-deleted parent reads as:

- Joins do not filter the parent's `deleted_at`, because the tombstone still carries its name.
- A deleted account's name still shows.
- A deleted category reads "Uncategorised".

## Decision

**`TransactionDao.selectTransactions` becomes one joined select.** It is a typed drift join, so the list's filters, its order and its plan
test stay as they were. Three joins are added, all `LEFT OUTER`:

- `categories` on `category_id`;
- `accounts` aliased `source_account` on `account_id`;
- `accounts` aliased `destination_account` on `destination_account_id`.

None of the three tests `deleted_at`. `LEFT` keeps `transactions` as the outer loop, so the owner index still serves the `ORDER BY`. The
watch re-runs on a write to any of the three tables, so renaming an account or deleting a category updates the list at once.

- **The plan**, pinned by the DAO tests:
  - the same seek into the owner index as before (or into the category index when filtered by category), with no `TEMP B-TREE`;
  - one primary-key lookup each into `categories`, `source_account` and `destination_account`;
  - no `SCAN` anywhere.
- **The DAO returns a `TransactionListRow`.** This is a record of the transaction row, the joined category row (tombstone included) and the
  two account names. The source account is read with `readTable`. The foreign key guarantees it exists (ADR-0009 §4), so a missing one is a
  bug and is not handled as data.
- **The snapshot now holds `TransactionListItem`s.** Each item is the transaction, a `CategoryEntity?`, the account name and, for a
  transfer, the destination account name. `snapshot.transactions` remains as a derived getter for readers that need only the entities.
- **The repository decides the category.** It returns null, which reads "Uncategorised", in three cases:
  - the transaction has no category;
  - the joined category is a tombstone;
  - the category row will not map.

  In the last case the fault is the category's, not the transaction's. So the transaction stays listed and is not counted as unreadable
  (ADR-0011), and the category is logged once per stream, by id and reason.

- **Account names come through as plain strings.** The row shows only the names, so an account row is never mapped to an entity here, and
  an account that will not map cannot hide a transaction.

## Consequences

Positive:

- The list shows what the canvas draws, still in one statement per window. A screen of 50 rows makes at most 150 primary-key lookups inside
  that statement, never 150 queries.
- A rename or delete of a parent updates every visible row at once, with nothing cached in the bloc to go stale.
- "Uncategorised" for a deleted category is decided in one place, the repository, as ADR-0010 requires.

Negative:

- A write to `accounts` or `categories` now re-runs the list query too. A user writes those tables rarely.
- Each row now reads the joined columns of three more rows. That is cheap for a window of 50, and W9's 50k benchmark measures it.
- The list item duplicates names the accounts and categories features also own. That is the price of one statement, and the price ADR-0019
  already paid for balances.

## Alternatives rejected

**Stream the accounts and categories next to the list and join them in the bloc.** Three streams can be one emission apart, as ADR-0019
found for balances. The bloc would also hold lookup maps that the list's own query could have filled.

**Look up each row's parents as it renders.** This is the N+1 that the task exists to rule out.

**Filter tombstones in the join.** ADR-0010 rules this out. A deleted account's name would disappear from rows that still count on its
other side.
