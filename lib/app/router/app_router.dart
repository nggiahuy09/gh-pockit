import 'package:flutter/material.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/app/router/app_shell.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/accounts/presentation/pages/accounts_page.dart';
import 'package:ghpockit/features/budgets/presentation/pages/budgets_page.dart';
import 'package:ghpockit/features/dashboard/presentation/pages/home_page.dart';
import 'package:ghpockit/features/settings/presentation/pages/settings_page.dart';
import 'package:ghpockit/features/transactions/presentation/pages/transactions_page.dart';
import 'package:go_router/go_router.dart';

/// A function, not a global: a `GoRouter` owns navigation state, and a shared one would leak between tests.
///
/// Each tab keeps its own stack (ADR-0003). Builders resolve pages' dependencies from `getIt`; branches build lazily, so an unopened tab resolves nothing.
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
            GoRoute(
              path: Routes.accounts,
              name: RouteNames.accounts,
              builder: (BuildContext context, GoRouterState state) => AccountsPage(repository: getIt<AccountRepository>()),
            ),
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
