# ADR 0019 — An account's balance is one query over both tables, owned by the transactions side

## Status

Accepted — 2026-10-15 (W6 T6).

Amended 2026-10-24 by ADR-0020: the readers are now `AccountsBloc` and `HomeAccountsBloc`, and `AccountMapper` is the
`AccountRowMapper.toDomain()` extension.

## Context

W6 T6 shows real balances: on the Accounts tab, and in the accounts section of
Home. ADR-0009 fixes the arithmetic: the opening balance, plus income, minus
expenses, minus transfers out, plus transfers in, counting the arriving side
through `destination_account_id`. CLAUDE.md §6 rules out a stored balance
column with no recompute strategy, so the balance is computed when it is read.
ADR-0010 adds that a deleted account's transfers keep counting on the account
at the other end.

What was left open is where the query lives. The user chose between two
options on 2026-10-15:

1. **One SQL statement in the transactions data layer.** It selects the
   accounts, with a correlated `SUM` per side. `TransactionDao` already reads
   `accounts` (ADR-0010 rules 1–2), so the dependency keeps its one direction.
2. **Two streams merged in a use case.** The transactions repository returns
   only sums per account id. A use case merges them with
   `AccountRepository.watchAccounts()`.

## Decision

**One statement, in `TransactionDao.watchAccountBalances`, exposed as
`TransactionRepository.watchAccountBalances()`.** It returns a list of
`AccountBalance`, an account with its `Money` balance in the account's
currency.

- Each side is a correlated scalar subquery: the source side through
  `transactions_account_id_occurred_at_id`, the arriving side through
  `transactions_destination_account_id_occurred_at_id`. Both indexes exist
  since W4 (ADR-0009). A DAO test pins the plan: both indexes are searched, and
  the transactions table is never scanned.
- The list is the owner's live, unarchived accounts in creation order, the
  same rows and the same order as `AccountRepository.watchAccounts()`. The
  other account of a transfer is never joined, so a deleted account's
  transfers still count at the other end.
- A transaction whose type is none of the three adds nothing. Such a row is
  unreadable, and the list counts it (ADR-0011); the balance does not guess its
  sign.
- An account row that will not map fails the whole list with a
  `GPDatabaseFailure`, as `watchAccounts` does. A total with one account
  silently missing is worse than an error.
- The query reads from both tables, so it re-runs on any write to either.
- `WatchAccountBalancesUseCase` (accounts domain, ADR-0013) forwards it. The
  Accounts tab's `AccountsCubit` and Home's `HomeAccountsCubit` both read it,
  so the two screens can never show different balances for one account.

## Consequences

Positive:

- The accounts and their balances are one snapshot from one statement. No
  frame shows a new account next to an old sum, or the reverse.
- One query per change, not two, and one stream to subscribe to and test.
- Nothing is stored, so there is nothing to recompute, migrate or sync. The
  balance syncs because the transactions do.

Negative:

- The transactions data layer now returns a list of accounts, mapped with the
  accounts feature's `AccountMapper`. That is a second cross-feature read in
  the same direction as the first, not a new direction.
- Each correlated subquery reads every live transaction of its account
  through the index, with no covering index for `type`, `amount_minor` and
  `deleted_at`. That is fine for the accounts of one person today. W7 T2's
  `EXPLAIN QUERY PLAN` audit and W8's 50k-row benchmark decide whether it
  needs a covering index. The audit (2026-10-20) found no scan and added no
  index. An index on `(account_id, deleted_at, type, amount_minor)` does turn
  the source side into a covering-index search, but whether that saves enough
  to pay for one more index on every write is W8's to measure.
- Every transaction write re-runs the whole list. That is cheap with a handful
  of accounts, and the same trade the transaction list makes (ADR-0011).
- The `ORDER BY` on accounts uses a temporary B-tree, which is nothing for a
  few rows.

## Alternatives rejected

**Two streams merged in a use case.** The feature boundary is cleaner, but the
two can be one emission apart. It needs a hand-written `combineLatest`, since
the repo has no rxdart, and it runs two queries per change.

**A stored `balance` column** updated on every write. It breaks CLAUDE.md §6
unless there is a recompute strategy, it doubles every write, and in P4 it
would be a derived value that sync would have to keep consistent across
devices.

**The query in `AccountDao`.** The accounts data layer would then read
`transactions`, a second direction of dependency between the two features.
