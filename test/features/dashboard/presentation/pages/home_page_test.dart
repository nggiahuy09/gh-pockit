import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/app.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_balance.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/accounts/presentation/pages/account_form_page.dart';
import 'package:ghpockit/features/accounts/presentation/pages/accounts_page.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/dashboard/presentation/pages/home_page.dart';
import 'package:ghpockit/features/dashboard/presentation/pages/home_view.dart';
import 'package:ghpockit/features/transactions/domain/entities/category_spending.dart';
import 'package:ghpockit/features/transactions/domain/entities/income_expense_totals.dart';
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
      ..registerSingleton<TransactionRepository>(_repositories.transactions)
      ..registerSingleton<GPClock>(_repositories.clock);
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

  group('the month card', () {
    testWidgets("shows this month's income, spending and the difference; a transfer and last month count as neither", (tester) async {
      final cash = okValue(await _repositories.accounts.createAccount(initialBalance: Money(0, 'VND'), type: AccountType.cash, name: 'Cash wallet'));
      final bank = okValue(await _repositories.accounts.createAccount(initialBalance: Money(0, 'VND'), type: AccountType.bank, name: 'Salary'));
      await _record(TransactionType.income, 900000, DateTime(2026, 9, 1, 8), cash.id);
      await _record(TransactionType.expense, 45000, DateTime(2026, 9, 5), cash.id);
      await _record(TransactionType.expense, 1, DateTime(2026, 8, 31, 23), cash.id);
      await _record(TransactionType.transfer, 200000, DateTime(2026, 9, 6), cash.id, destinationAccountId: bank.id);
      await _pumpApp(tester);

      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('₫855,000'), findsOneWidget);
      expect(find.text('+₫900,000'), findsOneWidget);
      expect(find.text('-₫45,000'), findsOneWidget);
    });

    testWidgets('a month with nothing in it reads 0, unsigned, and the breakdown says there is no spending yet', (tester) async {
      await _seedAccount(AccountType.cash, 'Cash wallet');
      await _pumpApp(tester);

      expect(find.text('₫0'), findsNWidgets(4), reason: "net, income and spending, then the account's balance");
      expect(find.text('+₫0'), findsNothing);
      expect(find.text('-₫0'), findsNothing);
      expect(find.text('No spending this month yet'), findsOneWidget);
    });
  });

  group('spending by category', () {
    testWidgets('lists the three largest with their share, "Uncategorised" last, and the rest on one line', (tester) async {
      final cash = okValue(await _repositories.accounts.createAccount(initialBalance: Money(0, 'VND'), type: AccountType.cash, name: 'Cash wallet'));
      for (final (name, amount) in [('Food', 2140000), ('Bills', 1486000), ('Transport', 962000), ('Shopping', 890000), ('Fun', 420000)]) {
        final category = okValue(await _repositories.categories.createCategory(type: CategoryType.expense, name: name));
        await _record(TransactionType.expense, amount, DateTime(2026, 9, 5), cash.id, categoryId: category.id);
      }
      await _record(TransactionType.expense, 316000, DateTime(2026, 9, 6), cash.id);
      await _pumpApp(tester);

      expect(find.text('Spending by category'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('34%'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('Shopping'), findsNothing);
      expect(find.text('Uncategorised'), findsOneWidget);
      expect(find.text('2 more categories'), findsOneWidget);
      expect(find.text('₫1,310,000'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Uncategorised')).dy, greaterThan(tester.getTopLeft(find.text('Transport')).dy));
      expect(find.bySemanticsLabel("Food, ₫2,140,000, 34% of this month's spending"), findsOneWidget);
    });

    testWidgets('a breakdown that cannot be read shows its failure in place, and the rest of Home still shows', (tester) async {
      await getIt.unregister<TransactionRepository>();
      getIt.registerSingleton<TransactionRepository>(_FailingBreakdownRepository(_repositories.transactions));
      await _seedAccount(AccountType.cash, 'Cash wallet');
      await _pumpApp(tester);

      expect(find.text('Could not read local data.'), findsOneWidget);
      expect(find.text('This part comes back by itself the next time data is saved.'), findsOneWidget);
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('Cash wallet'), findsOneWidget);
    });
  });
}

Future<void> _record(TransactionType type, int minorUnits, DateTime at, String accountId, {String? categoryId, String? destinationAccountId}) async => okValue(
  await _repositories.transactions.createTransaction(
    amount: Money(minorUnits, 'VND'),
    type: type,
    occurredAt: at,
    accountId: accountId,
    categoryId: categoryId,
    destinationAccountId: destinationAccountId,
  ),
);

/// The real repository for everything but the breakdown, so the other sections still show.
final class _FailingBreakdownRepository extends FakeTransactionRepository {
  _FailingBreakdownRepository(this._real) : super(_real.watchAccountBalances());

  final TransactionRepository _real;

  @override
  Stream<IncomeExpenseTotals> watchIncomeExpenseTotals({required String currencyCode, required DateTime from, required DateTime to}) =>
      _real.watchIncomeExpenseTotals(currencyCode: currencyCode, from: from, to: to);

  @override
  Stream<List<CategorySpending>> watchSpendingByCategory({required String currencyCode, required DateTime from, required DateTime to}) => Stream.error(const GPDatabaseFailure());
}
