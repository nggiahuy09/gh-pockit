import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/app.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_balance.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/accounts/presentation/pages/account_form_page.dart';
import 'package:ghpockit/features/accounts/presentation/pages/accounts_page.dart';
import 'package:ghpockit/features/dashboard/presentation/pages/home_page.dart';
import 'package:ghpockit/features/dashboard/presentation/pages/home_view.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

import '../../../../helpers/fake_transaction_repository.dart';
import '../../../../helpers/in_memory_repositories.dart';
import '../../../../helpers/localization_harness.dart';
import '../../../../helpers/results.dart';

late InMemoryRepositories _repositories;

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.en)));
  await tester.pumpAndSettle();
}

Future<void> _seedAccount(AccountType type, String name) => _repositories.accounts.createAccount(initialBalance: Money(0, 'VND'), type: type, name: name);

/// The whole app over the real repository: Home reads the same rows the accounts list does, live.
void main() {
  setUp(() {
    _repositories = InMemoryRepositories();
    getIt
      ..registerSingleton<AccountRepository>(_repositories.accounts)
      ..registerSingleton<TransactionRepository>(_repositories.transactions);
  });

  tearDown(() async {
    await getIt.reset();
    await _repositories.close();
  });

  testWidgets('with no account, offers to add one', (tester) async {
    await _pumpApp(tester);

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);
  });

  testWidgets('lists the first accounts with their type, and "See all" opens the Accounts tab', (tester) async {
    await _seedAccount(AccountType.cash, 'Cash wallet');
    await _seedAccount(AccountType.bank, 'Salary');
    await _seedAccount(AccountType.eWallet, 'E-wallet');
    await _seedAccount(AccountType.creditCard, 'Card');
    await _pumpApp(tester);

    final shown = ['Cash wallet', 'Salary', 'E-wallet', 'Card'].where((name) => find.text(name).evaluate().isNotEmpty);
    expect(shown, hasLength(HomeView.accountsShown));
    expect(find.text('Bank'), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_outlined), findsOneWidget);

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountsPage), findsOneWidget);
  });

  testWidgets('an account added elsewhere shows up with no refresh', (tester) async {
    await _pumpApp(tester);

    await _seedAccount(AccountType.cash, 'Cash wallet');
    await tester.pumpAndSettle();

    expect(find.text('Cash wallet'), findsOneWidget);
  });

  testWidgets('a row opens that account in the form', (tester) async {
    await _seedAccount(AccountType.cash, 'Cash wallet');
    await _pumpApp(tester);

    await tester.tap(find.text('Cash wallet'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();

    expect(find.byType(AccountFormPage), findsOneWidget);
    expect(find.text('Edit account'), findsOneWidget);
  });

  testWidgets('each account shows its balance, the same the Accounts tab shows, and follows a new transaction', (tester) async {
    final cash = okValue(await _repositories.accounts.createAccount(initialBalance: Money(500000, 'VND'), type: AccountType.cash, name: 'Cash wallet'));
    await _pumpApp(tester);
    expect(find.text('₫500,000'), findsOneWidget);

    await _repositories.transactions.createTransaction(amount: Money(45000, 'VND'), type: TransactionType.expense, occurredAt: DateTime.utc(2026, 10, 15), accountId: cash.id);
    await tester.pumpAndSettle();

    expect(find.text('₫455,000'), findsOneWidget);
  });

  testWidgets('accounts that cannot be read show the failure, not an endless spinner', (tester) async {
    await getIt.unregister<TransactionRepository>();
    getIt.registerSingleton<TransactionRepository>(FakeTransactionRepository(Stream<List<AccountBalance>>.error(const GPDatabaseFailure())));
    await _pumpApp(tester);

    expect(find.text('Could not read local data.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
