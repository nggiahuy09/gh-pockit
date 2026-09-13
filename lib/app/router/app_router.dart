import 'package:flutter/material.dart';
import 'package:ghpockit/app/router/app_shell.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/features/accounts/presentation/pages/accounts_page.dart';
import 'package:ghpockit/features/budgets/presentation/pages/budgets_page.dart';
import 'package:ghpockit/features/dashboard/presentation/pages/home_page.dart';
import 'package:ghpockit/features/settings/presentation/pages/settings_page.dart';
import 'package:ghpockit/features/transactions/presentation/pages/transactions_page.dart';
import 'package:go_router/go_router.dart';

/// Builds the app router.
///
/// A function, not a global `final router = GoRouter(...)`: a `GoRouter` owns navigation state, and a global one is shared between tests, so test A
/// leaves test B on `/settings`. Every caller — `GPApp`, every widget test — gets its own instance.
///
/// [initialLocation] exists for tests and for deep-link entry: a widget test can start directly on `/budgets` and assert what the shell does with it,
/// which is exactly the case a hand-rolled `int _currentTab` would get wrong.
///
/// **Why `StatefulShellRoute.indexedStack` and not a plain `ShellRoute`** (ADR-0003): each branch keeps its own `Navigator` and its own stack, so
/// opening `/transactions/:id`, switching to Accounts and coming back returns to that detail page with its scroll position intact. A plain
/// `ShellRoute` has one `Navigator` for all five tabs and resets the stack on every tab switch — which would have to be undone in W5–W6 as soon as
/// the first child route exists.
GoRouter createRouter({String initialLocation = Routes.initial}) => GoRouter(
  initialLocation: initialLocation,
  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      builder: (BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) => AppShell(navigationShell: navigationShell),
      // Branch order defines the tab index. It must match `shellTabs` in app_shell.dart.
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[GoRoute(path: Routes.home, name: RouteNames.home, builder: (BuildContext context, GoRouterState state) => const HomePage())],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(path: Routes.accounts, name: RouteNames.accounts, builder: (BuildContext context, GoRouterState state) => const AccountsPage()),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.transactions,
              name: RouteNames.transactions,
              builder: (BuildContext context, GoRouterState state) => const TransactionsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(path: Routes.budgets, name: RouteNames.budgets, builder: (BuildContext context, GoRouterState state) => const BudgetsPage()),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(path: Routes.settings, name: RouteNames.settings, builder: (BuildContext context, GoRouterState state) => const SettingsPage()),
          ],
        ),
      ],
    ),
  ],
);
