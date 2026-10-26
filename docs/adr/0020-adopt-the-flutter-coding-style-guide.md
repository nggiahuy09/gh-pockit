# ADR 0020 — Adopt the Flutter coding style guide

## Status

Accepted — 2026-10-24 (W7). Amends ADR-0006, ADR-0012, ADR-0013 and ADR-0019 where they name a shape this changes.

## Context

The owner's Flutter coding style (`docs/coding-style-flutter.md`) is drawn from two production apps and is binding for the code they write. It was
applied to the whole repo in one pass during the W7 review week, not only to new code. The guide says a project's own rules win on conflict, so every
place where it meets CLAUDE.md needed a call. The owner made these on 2026-10-24.

## Decision

**The guide is binding; CLAUDE.md wins where they conflict.** What that means in practice:

Taken from the guide, everywhere:

- **Blocs only, no Cubits.** One `on<FeatureEvent>` (plus one per transformer group) running an exhaustive `switch` that delegates to `_xHandler`s;
  `sequential` for requests, `restartable` for watches (`core/bloc/transformers.dart`). A bloc starts itself in its constructor. Lists use one state
  class per transition (`XInitState`, `XLoadingState`, `XLoadedState`, `XLoadErrorState`); the two forms are single-state with a `status` enum and a
  private `_copyWith` taking `GPValueWrapper` for clearable fields.
- **Use cases** are `final class XUseCase with GPUseCase<XInput, Output>` (or `GPStreamUseCase`) called as `execute(XInput(...))`; the input is an
  immutable class implementing `GPLoggable`, `GPNoInput` when there is none. Repositories arrive positionally (ADR-0013 otherwise stands).
- **A Page provides the `BlocProvider` and has no UI; a View holds the layout**, the listeners and the navigation. The router builds pages.
- **Snackbars come from listeners.** The undo and the delete error are now states of `TransactionDeletionBloc`.
- **Entities, states, results and failures use `Equatable`** (new dependency, `equatable` 2.1.0). Entities that hold user text keep a redacting
  `toString` (golden rule 9).
- Every concrete class is `final` (`base` where a test subclasses it, plain `class` only for drift tables, with a comment saying why); field, parameter,
  call-site and member order follow the guide; a single parameter is positional; two of one type, or more than three, are named.
- Naming: feature widgets end in `Widget`; helpers are `<type>_extension.dart`, shared enums `<name>_enum.dart`; user-facing text comes from
  `getTitle(locale)` / `getMessage(locale)`; paired locale keys are `…Title` / `…Body`; events `{Noun}{Verb}Event`.
- Mappers are extensions — `row.toDomain()`, `entity.toInsert(ownerId)`, `entity.toPatch()` — still in `data/mapper/`.
- Comments only where a normal read would not give the reason.
- Lints: the guide wins over very_good_analysis on `always_use_package_imports` (now `prefer_relative_imports` in `lib/`), `prefer_int_literals`
  (doubles are written `16.0`), `always_put_required_named_parameters_first` and `avoid_positional_boolean_parameters`.

Kept from CLAUDE.md:

- The folder layout (`app/`, `core/`, `features/`, `pages/` holding both pages and views) and the file names (`_use_case.dart`, `_repository.dart`).
- `GPResult` / `GPFailure` instead of `Either` / `XXException` (ADR-0006).
- `context.l10n` through `GPLocalizationScope`, bound as `final locale = context.l10n;`.
- The git flow: merge commits, one PR per week.
- `Money(minorUnits, currencyCode)` and the design-token classes keep their order (role pairs, scales); each says so in one comment.

Decided where the guide and the project disagree:

1. **Repositories still log** database exceptions with their stack trace. That catch is the only place holding them, the equivalent of the guide's
   network interceptor; blocs log nothing until a remote logger exists.
2. **Repositories keep constructor injection.** Blocs resolve their use cases from `getIt` in field initializers, as the guide says; repository tests
   build the impl over an in-memory database without the locator.
3. **`AccountsBloc` and `HomeAccountsBloc` stay two blocs** in their own features, though they are the same watch (guide warning W5).

## Alternatives

**New code only** — the guide's own default. No churn, but two styles side by side for as long as the old code lives, and every review would argue which
one applies.

**Local rules only, structure later.** Mechanical changes now, Cubit→Bloc and the use-case inputs in a second pass. Cheaper per step, but it touches
every presentation file twice.

**`Either` from `fpdart` and the guide's exception hierarchy.** Matches the guide literally; replaces a working, tested result type with a library and
supersedes ADR-0006 for no new capability.

## Consequences

Positive:

- One style across lib and test, checkable: the field, parameter and call-site order rules are mechanical.
- Every write a bloc performs has a named input that can be logged without payload (`toLog()`).
- Feedback (snackbars, navigation) is driven by state, so it is testable through `bloc.stream`.

Negative:

- A large diff in one week, and the behaviour of four Cubits was rebuilt as Blocs: the bloc tests are what hold the old behaviour.
- `Equatable` compares `runtimeType`, so `GPOk<int>(1)` no longer equals `GPOk<num>(1)`; a generic helper must return `GPErr<T>(...)`, not a `const`
  `GPErr<Never>`.
- Field order by type and name scatters some related fields; where it would hurt (colours, scales, `Money`) the class opts out with a comment.
