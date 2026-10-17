import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/app.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_balance.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/accounts/presentation/pages/account_form_page.dart';
import 'package:ghpockit/features/accounts/presentation/pages/accounts_page.dart';
import 'package:ghpockit/features/dashboard/presentation/pages/home_page.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

import '../../../../helpers/fake_transaction_repository.dart';
import '../../../../helpers/in_memory_repositories.dart';
import '../../../../helpers/localization_harness.dart';

/// The whole app over the real repository: Home reads the same rows the accounts list does, live.
void main() {
  late InMemoryRepositories repositories;

  setUp(() {
    repositories = InMemoryRepositories();
    getIt
      ..registerSingleton<AccountRepository>(repositories.accounts)
      ..registerSingleton<TransactionRepository>(repositories.transactions);
  });

  tearDown(() async {
    await getIt.reset();
    await repositories.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.en)));
    await tester.pumpAndSettle();
  }

  Future<void> seedAccount(String name, AccountType type) => repositories.accounts.createAccount(name: name, type: type, initialBalance: Money(0, 'VND'));

  testWidgets('with no account, offers to add one', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);
  });

  testWidgets('lists the first accounts with their type, and "See all" opens the Accounts tab', (WidgetTester tester) async {
    await seedAccount('Cash wallet', AccountType.cash);
    await seedAccount('Salary', AccountType.bank);
    await seedAccount('E-wallet', AccountType.eWallet);
    await seedAccount('Card', AccountType.creditCard);
    await pumpApp(tester);

    final shown = <String>['Cash wallet', 'Salary', 'E-wallet', 'Card'].where((String name) => find.text(name).evaluate().isNotEmpty);
    expect(shown, hasLength(HomePage.accountsShown));
    expect(find.text('Bank'), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_outlined), findsOneWidget);

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountsPage), findsOneWidget);
  });

  testWidgets('an account added elsewhere shows up with no refresh', (WidgetTester tester) async {
    await pumpApp(tester);

    await seedAccount('Cash wallet', AccountType.cash);
    await tester.pumpAndSettle();

    expect(find.text('Cash wallet'), findsOneWidget);
  });

  testWidgets('a row opens that account in the form', (WidgetTester tester) async {
    await seedAccount('Cash wallet', AccountType.cash);
    await pumpApp(tester);

    await tester.tap(find.text('Cash wallet'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();

    expect(find.byType(AccountFormPage), findsOneWidget);
    expect(find.text('Edit account'), findsOneWidget);
  });

  testWidgets('each account shows its balance, the same the Accounts tab shows, and follows a new transaction', (WidgetTester tester) async {
    final cash = (await repositories.accounts.createAccount(name: 'Cash wallet', type: AccountType.cash, initialBalance: Money(500000, 'VND')) as GPOk<AccountEntity>).value;
    await pumpApp(tester);
    expect(find.text('₫500,000'), findsOneWidget);

    await repositories.transactions.createTransaction(type: TransactionType.expense, accountId: cash.id, amount: Money(45000, 'VND'), occurredAt: DateTime.utc(2026, 10, 15));
    await tester.pumpAndSettle();

    expect(find.text('₫455,000'), findsOneWidget);
  });

  testWidgets('accounts that cannot be read show the failure, not an endless spinner', (WidgetTester tester) async {
    await getIt.unregister<TransactionRepository>();
    getIt.registerSingleton<TransactionRepository>(FakeTransactionRepository(balances: Stream<List<AccountBalance>>.error(const GPDatabaseFailure())));
    await pumpApp(tester);

    expect(find.text('Could not read local data.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
