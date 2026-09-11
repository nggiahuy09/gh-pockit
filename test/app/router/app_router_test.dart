import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/app.dart';
import 'package:ghpockit/app/router/app_shell.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/features/accounts/presentation/pages/accounts_page.dart';
import 'package:ghpockit/features/budgets/presentation/pages/budgets_page.dart';
import 'package:ghpockit/features/dashboard/presentation/pages/home_page.dart';
import 'package:ghpockit/features/settings/presentation/pages/settings_page.dart';
import 'package:ghpockit/features/transactions/presentation/pages/transactions_page.dart';

/// Taps a bottom-navigation destination by its label.
///
/// Scoped to the [NavigationBar] on purpose: once a tab is open its name also appears in the app bar and in the page body, and an unscoped
/// `find.text('Accounts')` would match three widgets and fail.
Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

void main() {
  group('shell', () {
    testWidgets('starts on Home', (WidgetTester tester) async {
      await tester.pumpWidget(const GPApp());
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('renders one destination per tab, in branch order', (WidgetTester tester) async {
      await tester.pumpWidget(const GPApp());
      await tester.pumpAndSettle();

      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));

      // Guards the invariant asserted in AppShell: the destination list and the branch list are two hand-written lists that must stay the same
      // length and the same order, or tab N opens page M.
      expect(bar.destinations, hasLength(shellTabs.length));
      expect(
        bar.destinations.map((Widget d) => (d as NavigationDestination).label),
        <String>['Home', 'Accounts', 'Transactions', 'Budgets', 'Settings'],
      );
    });

    testWidgets('each tab opens its page and marks itself selected', (WidgetTester tester) async {
      await tester.pumpWidget(const GPApp());
      await tester.pumpAndSettle();

      final tabs = <String, Type>{
        'Accounts': AccountsPage,
        'Transactions': TransactionsPage,
        'Budgets': BudgetsPage,
        'Settings': SettingsPage,
        'Home': HomePage,
      };

      var index = 1;
      for (final entry in tabs.entries) {
        await tapTab(tester, entry.key);

        expect(find.byType(entry.value), findsOneWidget, reason: 'tapping ${entry.key} must show ${entry.value}');
        expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, index % shellTabs.length);
        index++;
      }
    });
  });

  group('deep link', () {
    testWidgets('opening a tab path directly renders that page with the right tab selected', (WidgetTester tester) async {
      // The case a hand-rolled `int _currentTab` gets wrong: the OS hands the app a path, and nothing taps anything.
      await tester.pumpWidget(const GPApp(initialLocation: Routes.budgets));
      await tester.pumpAndSettle();

      expect(find.byType(BudgetsPage), findsOneWidget);
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 3);
    });

    testWidgets('an unknown path does not take the shell down', (WidgetTester tester) async {
      await tester.pumpWidget(const GPApp(initialLocation: '/nope'));
      await tester.pumpAndSettle();

      // go_router's default error page. Asserted so that replacing it with a real 404 screen later is a deliberate, visible change.
      expect(tester.takeException(), isNull);
      expect(find.byType(HomePage), findsNothing);
    });
  });

  group('branch state', () {
    testWidgets('a visited tab stays alive after switching away', (WidgetTester tester) async {
      // This is the entire reason for StatefulShellRoute.indexedStack over a plain ShellRoute (ADR-0003). A plain ShellRoute has one Navigator for
      // all five tabs, so leaving Budgets would dispose its subtree — and in W5–W6 that means losing an open detail page and its scroll position.
      await tester.pumpWidget(const GPApp());
      await tester.pumpAndSettle();

      await tapTab(tester, 'Budgets');
      expect(find.byType(BudgetsPage), findsOneWidget);

      await tapTab(tester, 'Home');

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(BudgetsPage, skipOffstage: false), findsOneWidget, reason: 'the Budgets branch must survive the tab switch');
    });

    testWidgets('an unvisited tab is never built', (WidgetTester tester) async {
      // Lazy branches: five tabs must not mean five database subscriptions on the first frame.
      await tester.pumpWidget(const GPApp());
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage, skipOffstage: false), findsNothing);
    });
  });
}
