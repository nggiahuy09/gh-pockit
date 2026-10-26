# Codebase review — W7, October 2026

The W7 review of P1's code: a map of what exists, one transaction traced through every layer, and every place that wanted to be written differently,
each with a decision. It fed the style the repo now follows (`docs/coding-style-flutter.md`, ADR-0020). "Fixed in W7" items are already in the
`task/W7` commits; "when touched" items are fixed the next time a change lands in that file; "not fixing" items say why.

## 1. Map

`lib/` after the refactor: 181 files, 12.7k lines (generated code excluded). `test/`: 12.8k lines, 931 tests.

| Area                      | data | domain | presentation | Total |
| ------------------------- | ---: | -----: | -----------: | ----: |
| `features/transactions`   |  574 |    735 |        1,863 | 3,172 |
| `features/accounts`       |  351 |    302 |          909 | 1,562 |
| `features/categories`     |  413 |    161 |           58 |   632 |
| `features/settings`       |    — |      — |          407 |   407 |
| `features/dashboard`      |    — |      — |          230 |   230 |
| `features/budgets`        |    — |      — |           28 |    28 |
| `core/widgets`            |      |        |              | 3,083 |
| `core/localization`       |      |        |              | 1,462 |
| `core/theme`              |      |        |              |   805 |
| `core/` (everything else) |      |        |              |   769 |
| `app/` + `main.dart`      |      |        |              |   584 |

Half of `lib/` is shared UI: widgets, theme and strings. The domain of all three features together is 1.2k lines. That ratio is expected at the
end of P1, and it is why the review spent its time on the slices rather than on `core/widgets`.

## 2. One transaction, end to end

A new expense, from the Save button to the row in the list. Every arrow is checked against CLAUDE.md §2–§3 and the ADR that owns it.

1. **View → bloc.** `TransactionFormView` sends `TransactionFormSubmitEvent`
   (`lib/features/transactions/presentation/pages/transaction_form_view.dart:174`). No repository, no `Money` arithmetic in the widget (§3).
2. **Bloc → use case.** `_submitHandler` builds the `Money` and the occurred-at instant, emits `saving`, and calls
   `CreateTransactionUseCase.execute(CreateTransactionInput(...))` (`.../bloc/transaction_form_bloc.dart:170`, `:184`). The bloc reaches the
   domain only through use cases it built itself (ADR-0013).
3. **Use case → category rule.** `refusalFromCategory` reads the category and refuses one of the other kind (ADR-0010 rule 3,
   `.../domain/usecases/refusal_from_category.dart:7`), outside the write's transaction, a race the ADR accepts.
4. **Repository → entity.** `TransactionRepositoryImpl.createTransaction` mints a v7 id and runs `TransactionEntity.create`, which owns the
   entity's own rules: positive amount, transfer shape, note length (`.../data/repositories/transaction_repository_impl.dart:109`,
   `.../domain/entities/transaction_entity.dart:28`; ADR-0009, golden rule 4).
5. **Repository → DAO, one transaction.** The account rules (live account, same currency) and the insert share one Drift transaction, so sync cannot
   delete the account in between (`transaction_repository_impl.dart:137`; ADR-0010). The mapper's `toInsert` goes through `.insert`, so a new
   column is a compile error (`.../data/mapper/transaction_mapper.dart:62`); the DAO stamps `sync_status = pending` on every write
   (`.../data/daos/transaction_dao.dart:102`). The outbox mutation is not written yet: that is W13, and golden rule 3 is where it will land.
6. **Database → list.** Drift re-runs the live `watchTransactions` query; the repository maps rows with `toDomain()`, counts the ones it refuses,
   and emits a `TransactionListSnapshot` (`transaction_repository_impl.dart:41`, `:71`; ADR-0011).
7. **Use case → list bloc.** `TransactionListBloc._watchHandler` runs `emit.forEach` over `WatchTransactionsUseCase` under `restartable`, and
   drops anything a superseded query still sends (`.../bloc/transaction_list_bloc.dart:78`, `:84`; ADR-0012).
8. **Bloc → view.** `TransactionsView` rebuilds from `TransactionListLoadedState`, groups by local day and renders the row
   (`.../pages/transactions_view.dart:68`, `:170`).
9. **Form pops.** The form's listener sees `status == saved` and pops with `TransactionFormOutcome.saved` (`transaction_form_view.dart:48`). The
   list never receives the new row from the form: it reads it back from the database (golden rule 1).

Nothing on this path reads a network response, stores a derived balance, or uses a `double` for money.

## 3. Findings and decisions

| #   | Where                                                                    | Seen                                                                                                                                  | Wanted                                                                       | Why                                                                                                      | Decision                                                                  |
| --- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| 1   | All `presentation/bloc/`                                                 | One Bloc (`TransactionListBloc`) and six Cubits, two state-management shapes side by side                                             | Blocs only: events, one `on<>` per transformer group, `_xHandler`s           | One shape for W8–W28 to copy; events make every input loggable and testable                              | Fixed in W7 (ADR-0020)                                                    |
| 2   | `domain/usecases/*`                                                      | `call({named params})`, nothing to log a call by                                                                                      | `GPUseCase<XInput, Output>.execute(XInput)`, input implements `GPLoggable`   | A named input is the unit a log line and an idempotency key will be built from (P4)                      | Fixed in W7 (ADR-0020, amends ADR-0013)                                   |
| 3   | `app/router/app_router.dart`                                             | Route builders created providers and started cubits (`..start()`, `unawaited(cubit.load())`)                                          | The Page provides its bloc; the bloc starts itself                           | Creation and start in one place; the router only routes                                                  | Fixed in W7                                                               |
| 4   | `transactions_page.dart`, `settings_page.dart`                           | Cubit methods returned `GPResult` to the page, which showed the snackbar (`_UndoOffer`)                                               | Outcomes are states; snackbars come from a `BlocListener`                    | Feedback becomes testable through `bloc.stream`, and a page cannot forget to show it                     | Fixed in W7                                                               |
| 5   | Entities, states, `GPResult`, `GPFailure`, `Money`                       | ~15 hand-written `==` / `hashCode` pairs, each a place to forget a field                                                              | `Equatable` with `props`                                                     | A new field is one line in `props`, not two operators                                                    | Fixed in W7; new dependency, approved and recorded in ADR-0020            |
| 6   | `data/mapper/*`                                                          | Mapper classes injected through a default constructor parameter no caller ever overrode                                               | Extensions: `row.toDomain()`, `entity.toInsert(ownerId)`, `entity.toPatch()` | A seam nothing uses is noise                                                                             | Fixed in W7                                                               |
| 7   | DAOs and repository helpers                                              | Positional parameters of one type side by side (`watchAccount(ownerId, id)`); private helpers with four or five positional parameters | Named when two share a type or there are more than three                     | Swapping two `String`s compiles and returns the wrong row                                                | Fixed in W7                                                               |
| 8   | Every concrete class                                                     | No class modifiers                                                                                                                    | `final`, `base` where a test subclasses it                                   | The type says whether extending it is supported                                                          | Fixed in W7; drift tables stay plain `class` (drift subclasses them)      |
| 9   | Comments across `lib/` and `test/`                                       | ~740 comment lines; many restated a name or carried week/task provenance                                                              | Only the reason a normal read would not give, one line, an ADR pointer       | Restating comments rot; provenance belongs in git and the ROADMAP                                        | Fixed in W7 (~585 left, all "why"); trim further when touched             |
| 10  | Blocs, skeleton widgets, tests                                           | Local functions (`isCurrent()`, `bar()`, helpers inside `main()`)                                                                     | Private methods, private widgets, top-level test helpers                     | A local function cannot be found, named in a stack trace, or reused                                      | Fixed in W7                                                               |
| 11  | `core/localization/locale_store.dart`                                    | A test double (`GPInMemoryLocaleStore`) shipped in `lib/`                                                                             | `test/helpers/in_memory_locale_store.dart`, unprefixed                       | CLAUDE.md §3: test doubles never leave `test/`                                                           | Fixed in W7                                                               |
| 12  | Tests                                                                    | `as GPOk<T>` casts; `// ignore: prefer_const_constructors`                                                                            | `okValue(result)`; values built through a helper                             | A cast fails with a type error instead of the failure the result carried                                 | Fixed in W7                                                               |
| 13  | `data/tables/transactions_table.dart`                                    | `// ignore: recursive_getters` on the `amount_minor` CHECK                                                                            | No ignore                                                                    | The guide bans ignores                                                                                   | Not fixing: drift's idiom; a table-level CHECK instead changes the schema |
| 14  | `accounts_bloc.dart`, `home_accounts_bloc.dart`                          | The same balances watch in two blocs (guide W5)                                                                                       | An abstract base, or Home reusing `AccountsBloc`                             | One fix instead of two                                                                                   | Not fixing: each feature owns its states (owner's call, ADR-0020)         |
| 15  | The three `*_repository_impl.dart`                                       | Identical `_databaseFailure`, `_reportQueryError`, `_logRejectedRow` and the same stream-transformer shape (guide W5)                 | One helper in `core/database`                                                | Every fix lands three times                                                                              | When touched: P4 adds repositories, extract with the fourth               |
| 16  | `core/localization/localization.dart:20,43`                              | `_strings[locale]!` (guide W6)                                                                                                        | An exhaustive `switch` over `GPLocale`                                       | A locale added without strings would crash instead of failing to compile                                 | When touched                                                              |
| 17  | `Money`, `GPColors`, `GPTypography`, `GPSpacing`, `GPRadii`, `GPShadows` | The field-order rule would sort role pairs and scales alphabetically                                                                  | Keep role/scale order                                                        | `primary` beside `onPrimary` is what a reader checks; `Money(minorUnits, currencyCode)` is golden rule 2 | Not fixing: each class carries a one-line exception comment               |
| 18  | `transaction_list_snapshot.dart`                                         | The snapshot now keeps the caller's list instead of copying it                                                                        | —                                                                            | The guide's form; the repository never mutates the list after building it                                | Accepted; restore `List.of` if a caller ever mutates                      |
| 19  | `transaction_form_bloc.dart`, `account_form_bloc.dart`                   | Under `sequential`, a submit queued behind a failed one retries; edits typed while saving apply after it                              | —                                                                            | The button refuses input while saving, so the queue is hard to reach                                     | Accepted                                                                  |
| 20  | `watch_accounts_use_case.dart`, `watch_categories_use_case.dart`         | The unused `includeArchived` / `type` parameters were dropped from the use cases; the repositories keep them                          | —                                                                            | No screen passed them                                                                                    | Re-add with an input when the archived-accounts screen arrives            |
| 21  | `lib/core/database/database.g.dart`                                      | Doc comments copied from table comments that no longer exist                                                                          | Regenerated                                                                  | Generated code should match its source                                                                   | Fixed in W7; diff was comments only                                       |
| 22  | ADRs, docs, README, CLAUDE.md, `ci.yml`                                  | Week pointers in the numbering from before W7 was inserted                                                                            | Shifted by one (W7–W16 → W8–W17); removed from `lib/` and `test/`            | A pointer to the wrong week sends a reader to the wrong plan                                             | Fixed in W7                                                               |
| 23  | `settings_page_test.dart`                                                | No widget test for the "seed dataset" snackbar: the fakes serve one single-use stream and throw on writes                             | A test over in-memory repositories                                           | The debug tool is the only way to fill the list by hand                                                  | When touched (W9 seeding)                                                 |

## 4. How the week went against its own rules

- **No behaviour change**: held for every screen, with the small exceptions in rows 18–20.
- **No new dependency**: broken once, for `equatable`, approved by the owner and recorded in ADR-0020; the ROADMAP rule now says so.
- **Tests green after every commit**: not held. The refactor changed APIs across every layer at once, so the twelve `task/W7` refactor commits are
  grouped by area and only the last one builds. The PR says so.
- **Assertions only change with a rename or a restructure**: mostly held. Tests that pinned a getter or an event that no longer exists
  (`isLoadingMore`, a second `Started`) were replaced by assertions on the new states; two `toString` checks now assert content rather than the
  exact text, since `Equatable` writes it.

## 5. What I learned

_To be written by the owner (ROADMAP rule 5)._
