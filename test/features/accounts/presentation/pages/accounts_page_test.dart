import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/theme/colors.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_balance.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/presentation/pages/accounts_page.dart';
import 'package:ghpockit/features/accounts/presentation/widgets/account_balance_list_widget.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

import '../../../../helpers/fake_transaction_repository.dart';
import '../../../../helpers/in_memory_repositories.dart';
import '../../../../helpers/localization_harness.dart';
import '../../../../helpers/results.dart';

late InMemoryRepositories _repositories;

Future<void> _useFake(FakeTransactionRepository fake) async {
  await getIt.unregister<TransactionRepository>();
  getIt.registerSingleton<TransactionRepository>(fake);
}

Future<void> _pumpPage(WidgetTester tester, [GPLocale locale = GPLocale.en]) async =>
    tester.pumpWidget(localizedHarness(localization: await localizationFor(locale), child: const AccountsPage()));

Future<AccountEntity> _create(Money initialBalance, AccountType type, String name) async =>
    okValue(await _repositories.accounts.createAccount(initialBalance: initialBalance, type: type, name: name));

Future<void> _record({required AccountEntity from, AccountEntity? to, required TransactionType type, required int minor}) async => okValue(
  await _repositories.transactions.createTransaction(
    amount: Money(minor, from.initialBalance.currencyCode),
    type: type,
    occurredAt: DateTime.utc(2026, 10, 15),
    accountId: from.id,
    destinationAccountId: to?.id,
  ),
);

/// Through the real repositories on in-memory drift; the fake stages only what that cannot: a list not yet arrived.
void main() {
  setUp(() {
    _repositories = InMemoryRepositories();
    getIt.registerSingleton<TransactionRepository>(_repositories.transactions);
  });

  tearDown(() async {
    await getIt.reset();
    await _repositories.close();
  });

  testWidgets('shows the skeleton until the first list arrives, named for a screen reader', (tester) async {
    final pending = StreamController<List<AccountBalance>>();
    addTearDown(pending.close);
    await _useFake(FakeTransactionRepository(pending.stream));

    await _pumpPage(tester);
    await tester.pump();

    expect(find.byType(AccountListSkeletonWidget), findsOneWidget);
    expect(find.bySemanticsLabel('Loading accounts'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no accounts', (tester) async {
    await _pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('No accounts yet'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('lists each account with its type and its balance, which with no transaction is the opening one', (tester) async {
    await _create(Money(1500000, 'VND'), AccountType.cash, 'Ví tiền mặt');
    await _create(Money(1234, 'USD'), AccountType.bank, 'Chase');

    await _pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Ví tiền mặt'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('₫1,500,000'), findsOneWidget);
    expect(find.text('Chase'), findsOneWidget);
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text(r'$12.34'), findsOneWidget);
  });

  testWidgets('heads the card with how many accounts there are and what the column is', (tester) async {
    await _create(Money(0, 'VND'), AccountType.cash, 'Ví tiền mặt');
    await _pumpPage(tester);
    await tester.pumpAndSettle();
    expect(find.text('1 account'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);

    await _create(Money(0, 'VND'), AccountType.bank, 'Vietcombank');
    await tester.pumpAndSettle();
    expect(find.text('2 accounts'), findsOneWidget);
  });

  testWidgets('the balance is the opening balance moved by every transaction, a transfer once on each side', (tester) async {
    final cash = await _create(Money(1500000, 'VND'), AccountType.cash, 'Ví tiền mặt');
    final bank = await _create(Money(0, 'VND'), AccountType.bank, 'Vietcombank');
    await _record(from: cash, type: TransactionType.expense, minor: 450000);
    await _record(from: cash, type: TransactionType.income, minor: 100000);
    await _record(from: cash, to: bank, type: TransactionType.transfer, minor: 200000);

    await _pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('₫950,000'), findsOneWidget, reason: '1,500,000 - 450,000 + 100,000 - 200,000');
    expect(find.text('₫200,000'), findsOneWidget);
  });

  testWidgets('follows a transaction written after it opened, with no refresh', (tester) async {
    final cash = await _create(Money(100000, 'VND'), AccountType.cash, 'Ví tiền mặt');
    await _pumpPage(tester);
    await tester.pumpAndSettle();
    expect(find.text('₫100,000'), findsOneWidget);

    await _record(from: cash, type: TransactionType.expense, minor: 30000);
    await tester.pumpAndSettle();

    expect(find.text('₫70,000'), findsOneWidget);
  });

  testWidgets('money owed keeps its minus sign, and red repeats it', (tester) async {
    await _create(Money(-500000, 'VND'), AccountType.creditCard, 'Thẻ tín dụng');

    await _pumpPage(tester);
    await tester.pumpAndSettle();

    final owed = tester.widget<Text>(find.text('-₫500,000'));
    expect(owed.style?.color, const GPColors.light().expense);
  });

  testWidgets('speaks the active language in the type and in the amount', (tester) async {
    await _create(Money(1500000, 'VND'), AccountType.cash, 'Ví tiền mặt');

    await _pumpPage(tester, GPLocale.vi);
    await tester.pumpAndSettle();

    expect(find.text('Tiền mặt'), findsOneWidget);
    expect(find.text('1.500.000\u00A0₫'), findsOneWidget);
  });

  testWidgets('shows an account created after it opened, with no refresh', (tester) async {
    await _pumpPage(tester);
    await tester.pumpAndSettle();
    expect(find.text('No accounts yet'), findsOneWidget);

    await _create(Money(25000000, 'VND'), AccountType.bank, 'Vietcombank');
    await tester.pumpAndSettle();

    expect(find.text('Vietcombank'), findsOneWidget);
    expect(find.text('No accounts yet'), findsNothing);
  });

  testWidgets('shows the failure message when a stored row cannot be read', (tester) async {
    // 'savings' is a type this build does not know.
    await _repositories.db
        .into(_repositories.db.accountsTable)
        .insert(
          AccountsTableCompanion.insert(
            id: 'broken',
            ownerId: localOwnerId,
            name: 'Ví hỏng',
            type: 'savings',
            currencyCode: 'VND',
            initialBalance: 0,
            isArchived: false,
            createdAt: 0,
            updatedAt: 0,
            version: 1,
          ),
        );

    await _pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Could not read local data.'), findsOneWidget);
    expect(find.text('The list comes back by itself the next time data is saved.'), findsOneWidget);
    expect(find.text('Ví hỏng'), findsNothing);
  });
}
