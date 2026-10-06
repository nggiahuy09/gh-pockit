# ADR 0013 — Presentation reaches the domain only through use cases it builds

## Status

Accepted — 2026-10-06 (W5 T3). Supersedes ADR-0010's "a use case exists only
when it owns a rule", and widens the injector's rule on who may call `getIt`;
the rest of ADR-0010 stands.

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
only safe through the use case").

Calling use cases settles that, and raises the next question: how a BLoC gets
them. Through its constructor, whoever creates the BLoC assembles them, and every
new use case or new input a screen hands to one means editing that site or the
DI module.

## Decision

**A BLoC calls use cases only, and builds them itself.**

- A BLoC never calls a repository method. Every operation a screen performs is a
  use case: one class per operation, a `call` method, repositories through its
  constructor.
- The BLoC builds its use cases in field initializers, from repositories it
  resolves through `getIt`. Use cases are not registered in DI, which holds
  infrastructure and repositories only. A BLoC's constructor carries what the
  screen hands it — an account id, say — and never a dependency. The owner's
  reasons: a BLoC serves one feature, and the inputs a screen passes to a use
  case change with the screen; that change should not mean editing DI.
- Use cases never touch `getIt`: they live in `domain/`, which does not import
  `app/`.
- A use case that only forwards — `WatchTransactionsUseCase` — is allowed. It
  owns no rule; it owns the boundary.
- Rules stay where ADR-0010 put them: in the entity, inside the repository's
  write transaction, or in a use case that needs another row.
- A use case arrives with the first screen that needs it, never ahead (§12.11):
  `DeleteTransactionUseCase` comes with W6 T4's delete.

## Alternatives

**Keep ADR-0010.** Fewer classes; the bypass stays one import away.

**Use cases through the BLoC's constructor** (what T3 first did). The BLoC can
reach only what it is given, and tests need no locator, but every creation site
assembles use cases.

**The BLoC registered as a DI factory.** Clean creation sites and a narrow BLoC,
but every input a screen passes goes through a factory signature in DI — the
editing this decision avoids.

**Optional constructor parameters that default to `getIt`.** Tests inject,
production builds; the BLoC still reaches the locator, so it narrows nothing
more than the decision above.

**A narrow repository interface per screen** — a `TransactionListReader` with
`watchTransactions` alone. Closes the bypass without a class per operation, but
splits each repository into role interfaces the impl must keep implementing, and
leaves the operation without a name in the domain.

## Consequences

Positive:

- A screen creates its BLoC with its own inputs only: `TransactionListBloc()`.
- The DI module lists infrastructure and repositories, nothing per screen.
- `domain/` stays free of the locator.

Negative:

- The narrowing is a convention: a BLoC that can call `getIt` can resolve any
  repository. Review holds the line — a BLoC resolves only the repositories its
  use cases take, and calls only use cases.
- BLoC tests register fakes in the global locator and reset it after each test.
- One forwarding class per operation without a rule.
- The use cases W4 registered in DI (`CreateTransactionUseCase`,
  `UpdateTransactionUseCase`, `DeleteAccountUseCase`) are no longer registered;
  the screens that need them build them.
- `AccountsPage` (W3, no BLoC yet) still reads `AccountRepository` directly — the
  one remaining exception.
