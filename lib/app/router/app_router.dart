import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/app/router/app_shell.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/features/accounts/presentation/bloc/account_form_cubit.dart';
import 'package:ghpockit/features/accounts/presentation/bloc/accounts_cubit.dart';
import 'package:ghpockit/features/accounts/presentation/pages/account_form_page.dart';
import 'package:ghpockit/features/accounts/presentation/pages/accounts_page.dart';
import 'package:ghpockit/features/budgets/presentation/pages/budgets_page.dart';
import 'package:ghpockit/features/dashboard/presentation/bloc/home_accounts_cubit.dart';
import 'package:ghpockit/features/dashboard/presentation/pages/home_page.dart';
import 'package:ghpockit/features/settings/presentation/pages/settings_page.dart';
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_deletion_cubit.dart';
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_form_cubit.dart';
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_list_bloc.dart';
import 'package:ghpockit/features/transactions/presentation/pages/transaction_form_page.dart';
import 'package:ghpockit/features/transactions/presentation/pages/transactions_page.dart';
import 'package:go_router/go_router.dart';

/// A function, not a global: a `GoRouter` owns navigation state, and a shared one would leak between tests.
///
/// Each tab keeps its own stack (ADR-0003). Builders resolve pages' dependencies from `getIt`; branches build lazily, so an unopened tab resolves nothing.
GoRouter createRouter({String initialLocation = Routes.initial}) => GoRouter(
  initialLocation: initialLocation,
  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      builder: (BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) => AppShell(navigationShell: navigationShell, location: state.uri.path),
      // Branch order defines the tab index. It must match `shellTabs` in app_shell.dart.
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.home,
              name: RouteNames.home,
              builder: (BuildContext context, GoRouterState state) => BlocProvider<HomeAccountsCubit>(create: (_) => HomeAccountsCubit()..start(), child: const HomePage()),
              routes: <RouteBase>[
                GoRoute(
                  path: 'settings',
                  name: RouteNames.settings,
                  builder: (BuildContext context, GoRouterState state) => const SettingsPage(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.accounts,
              name: RouteNames.accounts,
              builder: (BuildContext context, GoRouterState state) => BlocProvider<AccountsCubit>(create: (_) => AccountsCubit()..start(), child: const AccountsPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.transactions,
              name: RouteNames.transactions,
              builder: (BuildContext context, GoRouterState state) => MultiBlocProvider(
                providers: <BlocProvider<dynamic>>[
                  BlocProvider<TransactionListBloc>(create: (_) => TransactionListBloc()..add(const TransactionListStarted())),
                  BlocProvider<TransactionDeletionCubit>(create: (_) => TransactionDeletionCubit()),
                ],
                child: TransactionsPage(clock: getIt<GPClock>()),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(path: Routes.budgets, name: RouteNames.budgets, builder: (BuildContext context, GoRouterState state) => const BudgetsPage()),
          ],
        ),
      ],
    ),
    // Outside the shell: a form covers the dock.
    GoRoute(
      path: Routes.newTransaction,
      name: RouteNames.newTransaction,
      builder: (BuildContext context, GoRouterState state) => BlocProvider<TransactionFormCubit>(
        create: (_) => TransactionFormCubit()..start(),
        child: TransactionFormPage(clock: getIt<GPClock>()),
      ),
    ),
    GoRoute(
      path: Routes.editTransaction,
      name: RouteNames.editTransaction,
      builder: (BuildContext context, GoRouterState state) => BlocProvider<TransactionFormCubit>(
        create: (_) {
          final cubit = TransactionFormCubit(transactionId: state.pathParameters['transactionId'])..start();
          unawaited(cubit.load());
          return cubit;
        },
        child: TransactionFormPage(clock: getIt<GPClock>()),
      ),
    ),
    GoRoute(
      path: Routes.newAccount,
      name: RouteNames.newAccount,
      builder: (BuildContext context, GoRouterState state) => BlocProvider<AccountFormCubit>(create: (_) => AccountFormCubit(), child: const AccountFormPage()),
    ),
    GoRoute(
      path: Routes.editAccount,
      name: RouteNames.editAccount,
      builder: (BuildContext context, GoRouterState state) => BlocProvider<AccountFormCubit>(
        create: (_) {
          final cubit = AccountFormCubit(accountId: state.pathParameters['accountId']);
          unawaited(cubit.load());
          return cubit;
        },
        child: const AccountFormPage(),
      ),
    ),
  ],
);
