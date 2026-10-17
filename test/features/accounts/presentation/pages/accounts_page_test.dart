import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/theme/colors.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_balance.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/presentation/bloc/accounts_cubit.dart';
import 'package:ghpockit/features/accounts/presentation/pages/accounts_page.dart';
import 'package:ghpockit/features/accounts/presentation/widgets/account_balance_list.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

import '../../../../helpers/fake_transaction_repository.dart';
import '../../../../helpers/in_memory_repositories.dart';
import '../../../../helpers/localization_harness.dart';

/// Through the real repositories on in-memory drift; the fake stages only what that cannot: a list not yet arrived, an error that is not a `GPFailure`.
void main() {
  late InMemoryRepositories repositories;

  setUp(() {
    repositories = InMemoryRepositories();
    getIt.registerSingleton<TransactionRepository>(repositories.transactions);
  });

  tearDown(() async {
    await getIt.reset();
    await repositories.close();
  });

  Future<void> useFake(FakeTransactionRepository fake) async {
    await getIt.unregister<TransactionRepository>();
    getIt.registerSingleton<TransactionRepository>(fake);
  }

  Future<void> pumpPage(WidgetTester tester, {GPLocale locale = GPLocale.en}) async {
    await tester.pumpWidget(
      localizedHarness(
        child: BlocProvider<AccountsCubit>(create: (_) => AccountsCubit()..start(), child: const AccountsPage()),
        localization: await localizationFor(locale),
      ),
    );
  }

  Future<AccountEntity> create(String name, AccountType type, Money initialBalance) async {
    final result = await repositories.accounts.createAccount(name: name, type: type, initialBalance: initialBalance);
    return (result as GPOk<AccountEntity>).value;
  }

  Future<void> record(TransactionType type, AccountEntity from, int minor, {AccountEntity? to}) async {
    final result = await repositories.transactions.createTransaction(
      type: type,
      accountId: from.id,
      destinationAccountId: to?.id,
      amount: Money(minor, from.initialBalance.currencyCode),
      occurredAt: DateTime.utc(2026, 10, 15),
    );
    expect(result, isA<GPOk<Object>>());
  }

  testWidgets('shows the skeleton until the first list arrives, named for a screen reader', (WidgetTester tester) async {
    final pending = StreamController<List<AccountBalance>>();
    addTearDown(pending.close);
    await useFake(FakeTransactionRepository(balances: pending.stream));

    await pumpPage(tester);
    await tester.pump();

    expect(find.byType(AccountListSkeleton), findsOneWidget);
    expect(find.bySemanticsLabel('Loading accounts'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no accounts', (WidgetTester tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('No accounts yet'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('lists each account with its type and its balance, which with no transaction is the opening one', (WidgetTester tester) async {
    await create('Ví tiền mặt', AccountType.cash, Money(1500000, 'VND'));
    await create('Chase', AccountType.bank, Money(1234, 'USD'));

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Ví tiền mặt'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('₫1,500,000'), findsOneWidget);
    expect(find.text('Chase'), findsOneWidget);
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text(r'$12.34'), findsOneWidget);
  });

  testWidgets('heads the card with how many accounts there are and what the column is', (WidgetTester tester) async {
    await create('Ví tiền mặt', AccountType.cash, Money(0, 'VND'));
    await pumpPage(tester);
    await tester.pumpAndSettle();
    expect(find.text('1 account'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);

    await create('Vietcombank', AccountType.bank, Money(0, 'VND'));
    await tester.pumpAndSettle();
    expect(find.text('2 accounts'), findsOneWidget);
  });

  testWidgets('the balance is the opening balance moved by every transaction, a transfer once on each side', (WidgetTester tester) async {
    final cash = await create('Ví tiền mặt', AccountType.cash, Money(1500000, 'VND'));
    final bank = await create('Vietcombank', AccountType.bank, Money(0, 'VND'));
    await record(TransactionType.expense, cash, 450000);
    await record(TransactionType.income, cash, 100000);
    await record(TransactionType.transfer, cash, 200000, to: bank);

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('₫950,000'), findsOneWidget, reason: '1,500,000 - 450,000 + 100,000 - 200,000');
    expect(find.text('₫200,000'), findsOneWidget);
  });

  testWidgets('follows a transaction written after it opened, with no refresh', (WidgetTester tester) async {
    final cash = await create('Ví tiền mặt', AccountType.cash, Money(100000, 'VND'));
    await pumpPage(tester);
    await tester.pumpAndSettle();
    expect(find.text('₫100,000'), findsOneWidget);

    await record(TransactionType.expense, cash, 30000);
    await tester.pumpAndSettle();

    expect(find.text('₫70,000'), findsOneWidget);
  });

  testWidgets('money owed keeps its minus sign, and red repeats it', (WidgetTester tester) async {
    await create('Thẻ tín dụng', AccountType.creditCard, Money(-500000, 'VND'));

    await pumpPage(tester);
    await tester.pumpAndSettle();

    final owed = tester.widget<Text>(find.text('-₫500,000'));
    expect(owed.style?.color, const GPColors.light().expense);
  });

  testWidgets('speaks the active language in the type and in the amount', (WidgetTester tester) async {
    await create('Ví tiền mặt', AccountType.cash, Money(1500000, 'VND'));

    await pumpPage(tester, locale: GPLocale.vi);
    await tester.pumpAndSettle();

    expect(find.text('Tiền mặt'), findsOneWidget);
    // The space is intl's non-breaking one.
    expect(find.text('1.500.000\u00A0₫'), findsOneWidget);
  });

  testWidgets('shows an account created after it opened, with no refresh', (WidgetTester tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();
    expect(find.text('No accounts yet'), findsOneWidget);

    await create('Vietcombank', AccountType.bank, Money(25000000, 'VND'));
    await tester.pumpAndSettle();

    expect(find.text('Vietcombank'), findsOneWidget);
    expect(find.text('No accounts yet'), findsNothing);
  });

  testWidgets('shows the failure message when a stored row cannot be read', (WidgetTester tester) async {
    // 'savings' is a type this build does not know.
    await repositories.db
        .into(repositories.db.accountsTable)
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

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Could not read local data.'), findsOneWidget);
    expect(find.text('The list comes back by itself the next time data is saved.'), findsOneWidget);
    expect(find.text('Ví hỏng'), findsNothing);
  });
}
