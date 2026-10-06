import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/app.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/app/router/app_shell.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/accounts/presentation/pages/accounts_page.dart';
import 'package:ghpockit/features/budgets/presentation/pages/budgets_page.dart';
import 'package:ghpockit/features/dashboard/presentation/pages/home_page.dart';
import 'package:ghpockit/features/settings/presentation/pages/settings_page.dart';
import 'package:ghpockit/features/transactions/presentation/pages/transactions_page.dart';

import '../../helpers/fake_account_repository.dart';
import '../../helpers/localization_harness.dart';

/// Scoped to the [NavigationBar]: an open tab's name also appears in the app bar and the page body.
Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

void main() {
  // The Accounts route resolves its repository from the global locator (see `createRouter`), so no private `GetIt` here. No test reads an account.
  setUp(() => getIt.registerSingleton<AccountRepository>(FakeAccountRepository()));
  tearDown(getIt.reset);

  group('shell', () {
    testWidgets('starts on Home', (WidgetTester tester) async {
      await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.en)));
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('renders one destination per tab, in branch order', (WidgetTester tester) async {
      await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.en)));
      await tester.pumpAndSettle();

      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));

      expect(bar.destinations, hasLength(shellTabs.length));
      expect(
        bar.destinations.map((Widget d) => (d as NavigationDestination).label),
        <String>['Home', 'Accounts', 'Transactions', 'Budgets', 'Settings'],
      );
    });

    testWidgets('each tab opens its page and marks itself selected', (WidgetTester tester) async {
      await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.en)));
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
      await tester.pumpWidget(GPApp(initialLocation: Routes.budgets, localization: await localizationFor(GPLocale.en)));
      await tester.pumpAndSettle();

      expect(find.byType(BudgetsPage), findsOneWidget);
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 3);
    });

    testWidgets('an unknown path does not take the shell down', (WidgetTester tester) async {
      await tester.pumpWidget(GPApp(initialLocation: '/nope', localization: await localizationFor(GPLocale.en)));
      await tester.pumpAndSettle();

      // go_router's default error page, not Home: replacing it with a real 404 screen should be a visible change.
      expect(tester.takeException(), isNull);
      expect(find.byType(HomePage), findsNothing);
    });
  });

  group('branch state', () {
    testWidgets('a visited tab stays alive after switching away', (WidgetTester tester) async {
      await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.en)));
      await tester.pumpAndSettle();

      await tapTab(tester, 'Budgets');
      expect(find.byType(BudgetsPage), findsOneWidget);

      await tapTab(tester, 'Home');

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(BudgetsPage, skipOffstage: false), findsOneWidget, reason: 'the Budgets branch must survive the tab switch');
    });

    testWidgets('an unvisited tab is never built', (WidgetTester tester) async {
      await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.en)));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage, skipOffstage: false), findsNothing);
    });
  });
}
