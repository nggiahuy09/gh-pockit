# ADR 0010 — Rules that span entities: where they run, and what deleting a parent does

## Status

Accepted — 2026-09-27, before W4. Closes the question that
`AccountRepository.deleteAccount` (W2 T5) and `CategoryRepository.deleteCategory`
(W3 T6) both left for W4 — "cascade, block, or orphan". Implemented at W4 T6
(the repository rules) and W4 flex (the use cases).

## Context

`TransactionEntity` checks everything that is about itself: a positive amount,
a transfer's shape, the length of a note (W4 T2, ADR-0009). Three rules need
another entity's row, so the entity cannot check them:

1. The account — and a transfer's destination — exists, belongs to the owner and
   is not soft-deleted.
2. The transaction's currency is its account's currency, and a transfer's two
   accounts share one. `Money.+` throws on a mismatch, but a balance is a SQL
   `SUM` that never goes through `Money`: a USD row on a VND account is added as
   if it were dong, silently.
3. An expense is filed under an expense category and an income under an income
   one. Otherwise W7's category breakdown counts income as spending.

Then the reverse direction: deleting an account or a category that already has
transactions.

Two facts shape the answers. The background sync of P4 writes the same database
concurrently, so a check made outside the write can be stale by the time the
write lands. And some states cannot be prevented offline, only tolerated: device
A deletes an account while device B, offline, adds a transaction to it. After
both sync, that transaction points at a tombstone whatever either device checked.

## Decision

**Rules 1 and 2 run in `TransactionRepositoryImpl`, inside the same
`transaction {}` as the write** — the shape `AccountRepositoryImpl.updateAccount`
already uses for its follow-up read. They protect the balance itself, so they
have to hold at the moment of the write, not at the moment of a check.

- A missing or soft-deleted account is `GPNotFoundFailure`, which is what "no
  live row with that id" means everywhere else.
- A currency mismatch is a `GPValidationFailure` with its own code, added at
  W4 T6 together with the rule. A correct user can reach it — another device can
  edit the account (see _Still open_) — so it is a result, not a throw
  (ADR-0006).
- An archived account passes. An old transaction on an archived account must
  stay editable; keeping archived accounts out of the picker is presentation's
  job.

**Rule 3 runs in `CreateTransactionUseCase` and `UpdateTransactionUseCase`**
(W4 flex), which read the category through `CategoryRepository`. It is a rule
about meaning rather than storage — a row filed under the wrong kind of category
is still readable and its balance still computes — so it belongs in the domain,
and it is what gives those two use cases a reason to exist. A soft-deleted
category is refused there too, as `GPNotFoundFailure`; the mismatch code arrives
with the rule.

**Deleting an account that has live transactions is refused.**
`DeleteAccountUseCase` (W4 flex) asks `TransactionRepository` whether any live
transaction touches the account, on either side of a transfer, and if one does
it returns a failure whose message points to archiving — which exists for
exactly this: out of pickers and lists, with history and sync kept. It sits in
the domain for the same reason as rule 3: nothing in storage breaks when an
account with transactions is deleted — readers tolerate a deleted parent, below
— so the rule is about what deleting means, not about keeping rows
interpretable. `AccountRepository.deleteAccount` stays unguarded, and callers go
through the use case. Cascade is rejected outright: soft-deleting a transfer A→B together
with A changes B's balance and B's history, on an account the user never
touched.

**Deleting a category that has transactions is allowed, and nothing else is
written.** The transactions keep their `category_id`, and every reader resolves a
soft-deleted category as "Uncategorised". One row changes, one mutation syncs,
and no conflicts are manufactured on rows the user did not touch. Setting
`category_id = NULL` instead would rewrite N rows and push N mutations to say the
same thing.

**Every reader tolerates a soft-deleted parent**, because sync produces one
whatever the rules above do:

- joins do not filter the parent's `deleted_at` (W7 T5) — the tombstone still
  carries its name, so a list can still say which account a transaction was on;
- a deleted account's transfers keep counting on the account at the other end;
- a deleted category's spending shows as "Uncategorised" in analytics (W7) and
  in budgets (W24).

**A use case exists only when it owns a rule.** Hence
`CreateTransactionUseCase`, `UpdateTransactionUseCase` and
`DeleteAccountUseCase` — and no `DeleteTransactionUseCase`: deleting a
transaction has no rule beyond what the repository already does, and a use case
that forwards one call is the pass-through §12.2 rejects, one layer up. A BLoC
calls the repository directly for such an operation. ADR-0006's open question —
whether a use case ever translates a failure — stays open; none of these three
needs to.

## Alternatives

**Every rule in the repository.** Atomic and in one place. Rejected for rule 3:
`data/` would be deciding what a category means, which is domain policy.

**Every rule in use cases.** Clean layering. Rejected for rules 1 and 2: a check
outside the write transaction is one the background sync can invalidate, and
these two protect the balance.

**Block deleting a category too.** Simple, but the user would have to re-file
every transaction first, for a category they want gone.

**Leave an account's transactions orphaned on delete.** A simple delete, but it
leaves a balance nobody can see that still moves the accounts at the other end
of its transfers. Archive already covers "get it out of the way".

**Cascade.** Rewrites other accounts' histories; see above.

## Consequences

Positive:

- The two rules that protect the balance hold at the moment of the write.
- Deleting a category is one row and one mutation.
- Every use case that exists has a job; none forwards a single call.

Negative:

- Features now depend on each other, one direction per layer: the transactions
  data layer reads `accounts` rows (rules 1–2), its use cases read
  `CategoryRepository`, and `DeleteAccountUseCase` reads `TransactionRepository`.
- `deleteAccount` is only safe through the use case. A caller that goes straight
  to the repository skips the rule; the method's dartdoc says so.
- The use-case checks run outside the write transaction, so sync can still slip
  a transaction under an account or a category between check and write — one
  more reason readers tolerate orphans.
- "Uncategorised" needs a string in both languages when W5 or W6 first renders
  one.

## Still open

- **An account's currency and a category's type are both editable today.**
  `AccountEntity.update(initialBalance:)` accepts a `Money` in another currency,
  and `CategoryEntity.update(type:)` flips expense and income. Either edit
  strands every transaction already under the row — rule 2 or rule 3 broken
  after the fact, with no write left to refuse. Decide before W6 exposes either
  edit: freeze them once the row has transactions, or freeze them outright.
