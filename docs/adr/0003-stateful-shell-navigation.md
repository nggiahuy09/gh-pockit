# ADR 0003 — Bottom navigation on `StatefulShellRoute.indexedStack`

## Status

Accepted — 2026-09-11 (W1 T6)

## Context

W1 T6 is the navigation skeleton: a five-tab bottom bar over `/home`,
`/accounts`, `/transactions`, `/budgets`, `/settings`, with every page still
empty. Nothing about that description forces a hard choice today — but the
shape chosen today is the one W5–W6 build child routes on top of
(`/transactions/:id`, `/transactions/new`, `/accounts/:accountId`), and the
cost of changing it grows with every screen added.

The question the skeleton has to answer now: **when the user leaves a tab, what
happens to what they were looking at?**

Three concrete cases from the roadmap:

- W5: open a transaction from the list, switch to Accounts to check a balance,
  come back. Is the detail page still open?
- W5: scroll 300 rows into the transaction list, switch tab, come back. Is the
  scroll position still there?
- W6: half-fill the create-transaction form, tab away by accident. Is the form
  still filled?

`go_router` offers two shells, and they answer those three questions
differently.

## Decision

Use **`StatefulShellRoute.indexedStack`** with one `StatefulShellBranch` per
tab.

- Each branch owns its own `Navigator` and its own stack, so the three cases
  above all keep their state.
- Branch order is the tab index. It is defined once in `app_router.dart` and
  mirrored by `shellTabs` in `app_shell.dart`; a test asserts the two lists
  have the same length and order, because a silent drift means tab N opens
  page M.
- `AppShell` holds **no** `int _currentTab`. `navigationShell.currentIndex` is
  the only source of truth, which is what makes a deep link straight into
  `/budgets` select the Budgets tab with nothing to synchronise by hand.
- Re-tapping the **active** tab passes `initialLocation: true` (pop that branch
  back to its root — the platform convention); tapping a **different** tab
  passes `false`, or switching tabs would reset the branch we just chose this
  shell to preserve.
- Branches stay **lazy** (`preload` left at its default `false`). Five tabs
  must not mean five database subscriptions on the first frame once P1 wires
  Drift streams in. A test asserts an unvisited tab is never built.
- Tab paths are top-level (`/accounts`, not `/shell/accounts`) so each one is
  a deep link on its own, and paths/names live in `Routes` / `RouteNames`
  rather than as literals in widgets.
- `createRouter()` is a function, not a global `final router`. A `GoRouter`
  owns navigation state; a global one is shared between tests, so test A would
  leave test B on `/settings`.

### Deviation from `CLAUDE.md` §5: `go_router` 17.2.3, not 18.0.1

§5 pins 18.0.1. It does not install: 17.3.0+ requires Dart >=3.10 and 18.x
requires >=3.12, while `.fvmrc` pins Flutter 3.35.6 / Dart 3.9.2. 17.2.3 is the
newest release that resolves.

The SDK pin wins over the package pin — the same call already made for
`very_good_analysis` (10.0.0 held because 11.0.0 needs Dart 3.10). Bumping the
Flutter SDK is a decision with its own blast radius (CI image, lint baseline,
every transitive package) and does not belong inside a navigation task. §5 has
been corrected to 17.2.3 with the constraint noted, so the next person does not
rediscover this from a failed `pub get`.

Nothing in this ADR depends on a 17.3+ API: `StatefulShellRoute.indexedStack`
has existed since 10.x.

## Alternatives

**Plain `ShellRoute`** — what `docs/blueprint.md` §15 suggests. One `Navigator`
for all five tabs. Less code today: no branches, no `StatefulNavigationShell`.
Rejected because it answers all three questions above with "no" — switching
tabs rebuilds the stack from the new location, so the open detail page, the
scroll offset and the half-filled form are gone. Every one of those would come
back as a bug report in W5–W6, and the fix is this ADR's decision applied
late, after five screens are already written against the other shape.

**`ShellRoute` plus manual state preservation** — keep the single `Navigator`
and hold each tab's stack by hand (`PageStorageKey`, a stack of routes per tab,
an `IndexedStack` of `Navigator`s built ourselves). This is re-implementing
`StatefulShellRoute`, badly, in app code we then own and test. Rejected on
CLAUDE.md §12.11: writing infrastructure the dependency already ships.

**`PageView` / `IndexedStack` with no router for the tabs** — treat the bottom
bar as pure UI state and route only inside a tab. Simple, and it breaks deep
links: the OS handing the app `pockit://transactions/123` has no way to select
the Transactions tab, because the tab index lives in a widget's `setState`
rather than in the URL. Deep links are a blueprint §15 requirement, not a
maybe.

**Defer the decision, ship a stateless shell now** — the "it's just five empty
pages" argument. Rejected because the deferral is not free: W5's list, W6's
form and the first child route would all be written against the stateless
shape, so the migration cost is highest exactly when the decision finally
gets forced.

## Consequences

Positive:

- Tab state survives tab switches, which is what a bottom bar is expected to
  do on both platforms, and it holds automatically for every screen added
  later rather than being re-solved per screen.
- Deep links and the selected tab cannot disagree: both derive from the
  location.
- Child routes in W5–W6 hang off an existing branch — no shell refactor.
- Lazy branches keep the first frame cheap once tabs start opening Drift
  streams.

Negative:

- More machinery than a plain `ShellRoute`: five branches to declare, and a
  branch list that must stay in step with the destination list. Mitigated by
  the assert in `AppShell` and by the ordering test.
- Every branch that was visited stays in memory for the life of the app. For
  five tabs this is not a concern; if a future tab holds something expensive,
  it is that tab's job to release it, not the shell's.
- The blueprint's §15 suggestion of `ShellRoute` is now out of date. This ADR
  is the newer decision; the blueprint keeps its intent (a shell drives bottom
  navigation), this file owns the mechanism.
- `go_router` sits one minor line behind the version named in §5 until the
  Flutter SDK pin moves. Revisit when the SDK is bumped.
