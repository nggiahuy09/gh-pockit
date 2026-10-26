import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/app.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/widgets/field.dart';
import 'package:ghpockit/core/widgets/form_failure_banner.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/accounts/presentation/pages/account_form_page.dart';
import 'package:ghpockit/features/accounts/presentation/pages/accounts_page.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

import '../../../../helpers/in_memory_repositories.dart';
import '../../../../helpers/localization_harness.dart';
import '../../../../helpers/results.dart';

late InMemoryRepositories _repositories;

Future<void> _pumpApp(WidgetTester tester, String location) async {
  await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.en), initialLocation: location));
  await tester.pumpAndSettle();
}

Future<AccountEntity> _seedAccount(Money balance, String name) async =>
    okValue(await _repositories.accounts.createAccount(initialBalance: balance, type: AccountType.cash, name: name));

/// The label sits above the box, outside the `TextField`.
Finder _field(String label) => find.descendant(of: find.widgetWithText(GPField, label), matching: find.byType(TextField));

String? _errorOn(WidgetTester tester, String label) => tester.widget<GPField>(find.widgetWithText(GPField, label)).errorText;

/// For a one-shot read (`.first`): the database was opened outside the fake zone, so its future completes only in real time.
Future<void> _settleRead(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  await tester.pumpAndSettle();
}

/// The whole app over the real repository: a save is done only when the accounts list it lands on shows the change.
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

  testWidgets('the empty accounts list has its own add button, which opens the form', (tester) async {
    await _pumpApp(tester, Routes.accounts);

    await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountFormPage), findsOneWidget);
  });

  testWidgets('opened cold, a save lands on the accounts list instead of throwing on the pop', (tester) async {
    await _pumpApp(tester, Routes.newAccount);

    await tester.enterText(_field('Name'), 'Ví tiền mặt');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AccountsPage), findsOneWidget);
    expect(find.text('Ví tiền mặt'), findsOneWidget);
  });

  testWidgets('edit keeps the currency fixed and saves the rest in place', (tester) async {
    await _seedAccount(Money(1000, 'USD'), 'Ví đô');
    await _pumpApp(tester, Routes.accounts);

    await tester.tap(find.text('Ví đô'));
    await _settleRead(tester);

    expect(find.text('Edit account'), findsOneWidget);
    expect(find.text('The currency cannot change once the account exists.'), findsOneWidget);
    expect(tester.widget<TextField>(_field('Opening balance')).controller!.text, '10.00');

    await tester.enterText(_field('Name'), 'Ví USD');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountsPage), findsOneWidget);
    expect(find.text('Ví USD'), findsOneWidget);
    final stored = await tester.runAsync(() => _repositories.accounts.watchAccounts().first);
    expect(stored!.single.initialBalance, Money(1000, 'USD'));
  });

  testWidgets('a blank name is refused under the name field, which takes the focus back', (tester) async {
    await _pumpApp(tester, Routes.newAccount);
    await tester.tap(_field('Opening balance'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(_errorOn(tester, 'Name'), "Account name can't be empty.");
    expect(tester.widget<TextField>(_field('Name')).focusNode!.hasFocus, isTrue);
    expect(find.byType(GPFormFailureBanner), findsNothing);
    expect(find.byType(AccountFormPage), findsOneWidget);
  });

  testWidgets('a conflict on edit owns no field, so it is the banner', (tester) async {
    await _seedAccount(Money(0, 'VND'), 'Ví');
    await _pumpApp(tester, Routes.accounts);
    await tester.tap(find.text('Ví'));
    await _settleRead(tester);
    await tester.runAsync(() => _repositories.db.customStatement('UPDATE accounts SET version = version + 1'));

    await tester.enterText(_field('Name'), 'Ví mới');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _settleRead(tester);

    expect(find.widgetWithText(GPFormFailureBanner, 'This item was changed on another device.'), findsOneWidget);
    expect(_errorOn(tester, 'Name'), isNull);
  });
}
