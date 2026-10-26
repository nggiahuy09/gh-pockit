# ADR 0014 — A floating four-tab dock; Settings moves under Home

## Status

Accepted — 2026-10-11 (W5 Flex). Changes ADR-0003's tab set and bar widget; its
branch model (`StatefulShellRoute.indexedStack`, one stack per tab, lazy
branches, re-tap pops to root) stands.

## Context

ADR-0003 shipped five tabs on Material's `NavigationBar`: Home, Accounts,
Transactions, Budgets, Settings. The W5 design ("Pockit Design" canvas,
Foundations and W5 pages) replaces that bar with a pill-shaped dock that floats
over the content, with frosted glass, four tabs and a round add button beside it.
The user chose to build it as designed (2026-10-11).

Three things follow that the bar never had to answer:

1. **Where Settings goes.** It is not one of the four tabs. The design's
   Profile screen, which holds settings, opens from Home's header and still shows
   the dock with Home selected.
2. **What the add button opens.** The create form is W6.
3. **How a page avoids content stuck under a dock that floats over it.**

## Decision

- **Four tabs**: Home, Accounts, Transactions, Budgets, drawn by `AppShell`'s own
  dock. Frosted glass is `GPGlass` (`core/widgets/`), with its numbers in
  `GPGlassTokens`. The tint colors are existing roles (`background` light,
  `surface` dark, `accent` for the button), so no new color role is needed and the
  contrast test is unchanged.
- **Settings is a child of the Home branch**: `/home/settings`, opened from an
  icon in Home's app bar. It keeps the dock with Home selected, as the design
  shows. Re-tapping Home pops it, by ADR-0003's rule. When W6 builds Home's
  header, the profile entry replaces the icon and the route stays.
- **The add button shows on every tab root**, decided from the current path, and
  hides on a page pushed inside a tab (settings). The design left it off Accounts
  and Budgets; trying the app, the user wanted it on every tab (2026-10-11), since
  adding a transaction is the app's main action wherever the user is. It pushes `/transactions/new`, a top-level route, so a
  form covers the dock. Until W6 that route is a placeholder page.
- **The dock reserves its space through `MediaQuery.padding.bottom`.** The shell
  adds the dock's height plus its gap to the bottom inset it hands the pages, so
  a `ListView`, a `SliverSafeArea` or a `SafeArea` keeps its last row scrollable
  past the dock without knowing the dock exists.
- Dock labels clamp the system text scale at 1.3, as Material's bar does. Content
  pages do not clamp.

## Consequences

**Good.** One place reserves the dock's space, and pages stay unaware of it. The
tab set, the branch order and `shellTabs` remain the single source ADR-0003 asks
for. The route for the W6 form already exists.

**Bad.** The dock is our own widget, so it gives up `NavigationBar`'s built-in
semantics and keyboard handling. Each tab merges its semantics into one selected
button, and a test checks the selected flag. A backdrop blur also costs a
compositing layer on every frame the list scrolls. W9's benchmark measures scroll
jank and will show whether that matters on low-end Android.

**Owed.** Widget tests cannot render the blur, so only a device shows the glass.

## Alternatives rejected

**Keep `NavigationBar` and restyle it.** Its theme cannot float it, round it into a
pill or place a button beside it, and the design needs all three.

**Settings as a fifth, hidden branch.** A branch the dock never selects would leave
no tab highlighted on that screen. The design shows Home highlighted.

**The add button only on Home and Transactions**, as the design drew it. A
button that comes and goes between tabs read as a bug in use.
