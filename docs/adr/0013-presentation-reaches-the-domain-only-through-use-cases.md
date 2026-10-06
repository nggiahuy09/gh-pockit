# ADR 0013 — Presentation reaches the domain only through use cases

## Status

Accepted — 2026-10-06 (W5 T3). Supersedes ADR-0010's "a use case exists only
when it owns a rule"; the rest of ADR-0010 stands.

## Context

ADR-0010 let a BLoC call a repository directly when an operation had no rule of
its own — deleting a transaction, watching the list — on the grounds that a use
case forwarding one call is §12.2's pass-through, one layer up.
`TransactionListBloc` (W5 T3) was the first BLoC to do it.

The cost is reach. A repository interface is a whole feature's surface. A BLoC
that holds `TransactionRepository` to watch the list can just as well call
`updateTransaction` around `UpdateTransactionUseCase`'s category rule, and one
that holds `AccountRepository` can call `deleteAccount` around
`DeleteAccountUseCase` — the hole ADR-0010 itself names ("`deleteAccount` is
only safe through the use case"). Only review stood in the way.

## Decision

**Presentation — a BLoC, or a page that has none yet — depends on use cases
only, never on a repository.**

- Every operation a screen performs is a use case: one class per operation, a
  `call` method, repositories taken through the constructor. Classes still never
  call `getIt`; a route builder resolves the use case and hands it to the BLoC.
- A use case that only forwards — `WatchTransactionsUseCase` — is allowed. It
  owns no rule; what it owns is the boundary: a BLoC sees exactly the operations
  its screen performs.
- Rules stay where ADR-0010 put them: in the entity, inside the repository's
  write transaction, or in a use case that needs another row.
- A use case arrives with the first screen that needs it, never ahead (§12.11):
  `DeleteTransactionUseCase` comes with W6 T4's delete.
- The owning feature's DI module registers it.

## Alternatives

**Keep ADR-0010.** Fewer classes; the bypass stays one import away.

**A narrow repository interface per screen** — a `TransactionListReader` with
`watchTransactions` alone. Closes the bypass without a class per operation, but
splits each repository into role interfaces the impl must keep implementing, and
leaves the operation without a name in the domain.

## Consequences

Positive:

- A screen cannot reach a write around its rule: the bypass ADR-0010 documented
  is closed by construction.
- BLoC tests still drive a fake repository, through the real use case.

Negative:

- One forwarding class per operation without a rule, starting with
  `WatchTransactionsUseCase`.
- §12.2's pass-through now names repositories only.
- `AccountsPage` (W3, no BLoC yet) still reads `AccountRepository` directly — the
  one remaining exception.
