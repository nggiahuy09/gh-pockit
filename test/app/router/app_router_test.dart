import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/app.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/app/router/app_shell.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/widgets/button.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_balance.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/presentation/pages/account_form_page.dart';
import 'package:ghpockit/features/accounts/presentation/pages/accounts_page.dart';
import 'package:ghpockit/features/budgets/presentation/pages/budgets_page.dart';
import 'package:ghpockit/features/dashboard/presentation/pages/home_page.dart';
import 'package:ghpockit/features/settings/presentation/pages/settings_page.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:ghpockit/features/transactions/presentation/pages/transaction_form_page.dart';
import 'package:ghpockit/features/transactions/presentation/pages/transactions_page.dart';

import '../../helpers/fake_transaction_repository.dart';
import '../../helpers/localization_harness.dart';
import '../../helpers/shell_harness.dart';

void main() {
  setUp(registerShellFakes);
  tearDown(getIt.reset);

  Future<void> pumpApp(WidgetTester tester, {String? at}) async {
    await tester.pumpWidget(GPApp(initialLocation: at, localization: await localizationFor(GPLocale.en)));
    await tester.pumpAndSettle();
  }

  void expectSelected(WidgetTester tester, String label) {
    for (final tab in <String>['Home', 'Accounts', 'Transactions', 'Budgets']) {
      expect(tester.getSemantics(dockLabel(tab)), tab == label ? containsSemantics(isSelected: true) : isNot(containsSemantics(isSelected: true)), reason: tab);
    }
  }

  group('shell', () {
    testWidgets('starts on Home', (WidgetTester tester) async {
      await pumpApp(tester);

      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('renders one dock tab per branch, in branch order', (WidgetTester tester) async {
      await pumpApp(tester);

      final labels = <String>['Home', 'Accounts', 'Transactions', 'Budgets'];
      expect(shellTabs, hasLength(labels.length));
      final xs = <double>[for (final label in labels) tester.getCenter(dockLabel(label)).dx];
      expect(xs, orderedEquals(<double>[...xs]..sort()));
    });

    testWidgets('a snackbar shown in the shell sits above the dock, not under it', (WidgetTester tester) async {
      await pumpApp(tester);

      ScaffoldMessenger.of(tester.element(find.byType(HomePage))).showSnackBar(const SnackBar(content: Text('Saved')));
      await tester.pumpAndSettle();

      // The Material, not the SnackBar: the widget's own box includes the inset that lifts it.
      final snackBar = tester.getRect(find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first);
      expect(snackBar.bottom, lessThanOrEqualTo(tester.getRect(find.byKey(AppShell.dockKey)).top));
    });

    testWidgets('each tab opens its page and marks itself selected', (WidgetTester tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);

      final tabs = <String, Type>{'Accounts': AccountsPage, 'Transactions': TransactionsPage, 'Budgets': BudgetsPage, 'Home': HomePage};
      for (final entry in tabs.entries) {
        await tapTab(tester, entry.key);

        expect(find.byType(entry.value), findsOneWidget, reason: 'tapping ${entry.key} must show ${entry.value}');
        expectSelected(tester, entry.key);
      }
      handle.dispose();
    });
  });

  group('add button', () {
    testWidgets('shows on every tab root', (WidgetTester tester) async {
      await pumpApp(tester);
      expect(find.byKey(AppShell.addButtonKey), findsOneWidget);

      for (final tab in <String>['Accounts', 'Transactions', 'Budgets', 'Home']) {
        await tapTab(tester, tab);
        expect(find.byKey(AppShell.addButtonKey), findsOneWidget, reason: tab);
      }
    });

    testWidgets('opens the add page over the dock, and back returns to the tab', (WidgetTester tester) async {
      await pumpApp(tester, at: Routes.transactions);

      await tester.tap(find.byKey(AppShell.addButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(TransactionFormPage), findsOneWidget);
      expect(find.byKey(AppShell.dockKey), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(TransactionsPage), findsOneWidget);
    });

    testWidgets('with no account yet, leads on to the account form', (WidgetTester tester) async {
      await pumpApp(tester, at: Routes.newTransaction);

      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountFormPage), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(TransactionFormPage), findsOneWidget);
    });
  });

  group('accounts', () {
    testWidgets('the app bar opens the account form over the dock', (WidgetTester tester) async {
      // With one account: an empty list hides the app bar's + behind its own add button.
      final wallet =
          (AccountEntity.create(id: 'acc-1', name: 'Ví', type: AccountType.cash, initialBalance: Money(0, 'VND'), createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026))
                  as GPOk<AccountEntity>)
              .value;
      await getIt.unregister<TransactionRepository>();
      getIt.registerSingleton<TransactionRepository>(
        FakeTransactionRepository(
          balances: Stream<List<AccountBalance>>.value(<AccountBalance>[AccountBalance(account: wallet, balance: Money(0, 'VND'))]),
        ),
      );
      await pumpApp(tester, at: Routes.accounts);

      await tester.tap(find.byTooltip('Add account'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountFormPage), findsOneWidget);
      expect(find.byKey(AppShell.dockKey), findsNothing);
    });

    testWidgets('with no account the app bar has no +: the empty state carries the one add button', (WidgetTester tester) async {
      await pumpApp(tester, at: Routes.accounts);

      expect(find.byTooltip('Add account'), findsNothing);
      expect(find.widgetWithText(GPButton, 'Add account'), findsOneWidget);
    });
  });

  group('settings', () {
    testWidgets('opens from Home, keeps the dock, and hides the add button', (WidgetTester tester) async {
      await pumpApp(tester);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byKey(AppShell.dockKey), findsOneWidget);
      expect(find.byKey(AppShell.addButtonKey), findsNothing);
    });

    testWidgets('re-tapping Home pops settings back to the Home root', (WidgetTester tester) async {
      await pumpApp(tester, at: Routes.settings);
      expect(find.byType(SettingsPage), findsOneWidget);

      await tapTab(tester, 'Home');

      expect(find.byType(SettingsPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
    });
  });

  group('deep link', () {
    testWidgets('opening a tab path directly renders that page with the right tab selected', (WidgetTester tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, at: Routes.budgets);

      expect(find.byType(BudgetsPage), findsOneWidget);
      expectSelected(tester, 'Budgets');
      handle.dispose();
    });

    testWidgets('an unknown path does not take the shell down', (WidgetTester tester) async {
      await pumpApp(tester, at: '/nope');

      // go_router's default error page, not Home: replacing it with a real 404 screen should be a visible change.
      expect(tester.takeException(), isNull);
      expect(find.byType(HomePage), findsNothing);
    });
  });

  group('branch state', () {
    testWidgets('a visited tab stays alive after switching away', (WidgetTester tester) async {
      await pumpApp(tester);

      await tapTab(tester, 'Budgets');
      expect(find.byType(BudgetsPage), findsOneWidget);

      await tapTab(tester, 'Home');

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(BudgetsPage, skipOffstage: false), findsOneWidget, reason: 'the Budgets branch must survive the tab switch');
    });

    testWidgets('an unvisited tab is never built', (WidgetTester tester) async {
      await pumpApp(tester);

      expect(find.byType(TransactionsPage, skipOffstage: false), findsNothing);
    });
  });
}
