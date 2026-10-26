import 'package:go_router/go_router.dart';

import '../../core/utils/clock.dart';
import '../../features/accounts/presentation/pages/account_form_page.dart';
import '../../features/accounts/presentation/pages/accounts_page.dart';
import '../../features/budgets/presentation/pages/budgets_page.dart';
import '../../features/dashboard/presentation/pages/home_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/transactions/presentation/pages/transaction_form_page.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';
import '../di/injector.dart';
import 'app_shell.dart';
import 'routes.dart';

/// A function, not a global: a `GoRouter` owns navigation state, and a shared one would leak between tests. Each tab keeps its own stack (ADR-0003);
/// branches build lazily, so an unopened tab resolves nothing.
GoRouter createRouter([String initialLocation = Routes.initial]) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, state, navigationShell) => AppShell(navigationShell: navigationShell, location: state.uri.path),
      // Branch order defines the tab index. It must match `shellTabs` in app_shell.dart.
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.home,
              name: RouteNames.home,
              builder: (_, _) => const HomePage(),
              routes: [GoRoute(path: 'settings', name: RouteNames.settings, builder: (_, _) => const SettingsPage())],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.accounts, name: RouteNames.accounts, builder: (_, _) => const AccountsPage())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.transactions,
              name: RouteNames.transactions,
              builder: (_, _) => TransactionsPage(clock: getIt.get<GPClock>()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.budgets, name: RouteNames.budgets, builder: (_, _) => const BudgetsPage())],
        ),
      ],
    ),
    // Outside the shell: a form covers the dock.
    GoRoute(
      path: Routes.newTransaction,
      name: RouteNames.newTransaction,
      builder: (_, _) => TransactionFormPage(clock: getIt.get<GPClock>()),
    ),
    GoRoute(
      path: Routes.editTransaction,
      name: RouteNames.editTransaction,
      builder: (_, state) => TransactionFormPage(clock: getIt.get<GPClock>(), transactionId: state.pathParameters['transactionId']),
    ),
    GoRoute(path: Routes.newAccount, name: RouteNames.newAccount, builder: (_, _) => const AccountFormPage()),
    GoRoute(
      path: Routes.editAccount,
      name: RouteNames.editAccount,
      builder: (_, state) => AccountFormPage(accountId: state.pathParameters['accountId']),
    ),
  ],
);
