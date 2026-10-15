import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/app.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/widgets/field.dart';
import 'package:ghpockit/core/widgets/form_failure_banner.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/accounts/presentation/pages/account_form_page.dart';
import 'package:ghpockit/features/accounts/presentation/pages/accounts_page.dart';

import '../../../../helpers/in_memory_repositories.dart';
import '../../../../helpers/localization_harness.dart';

/// The whole app over the real repository: a save is done only when the accounts list it lands on shows the change.
void main() {
  late InMemoryRepositories repositories;

  setUp(() {
    repositories = InMemoryRepositories();
    getIt.registerSingleton<AccountRepository>(repositories.accounts);
  });

  tearDown(() async {
    await getIt.reset();
    await repositories.close();
  });

  Future<void> pumpApp(WidgetTester tester, {required String at}) async {
    await tester.pumpWidget(GPApp(initialLocation: at, localization: await localizationFor(GPLocale.en)));
    await tester.pumpAndSettle();
  }

  Future<AccountEntity> seedAccount(String name, Money balance) async =>
      ((await repositories.accounts.createAccount(name: name, type: AccountType.cash, initialBalance: balance)) as GPOk<AccountEntity>).value;

  /// The label sits above the box, outside the `TextField`.
  Finder field(String label) => find.descendant(of: find.widgetWithText(GPField, label), matching: find.byType(TextField));

  String? errorOn(WidgetTester tester, String label) => tester.widget<GPField>(find.widgetWithText(GPField, label)).errorText;

  /// For a one-shot read (`.first`): the database was opened outside the fake zone, so its future completes only in real time.
  Future<void> settleRead(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();
  }

  testWidgets('the empty accounts list has its own add button, which opens the form', (WidgetTester tester) async {
    await pumpApp(tester, at: Routes.accounts);

    await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountFormPage), findsOneWidget);
  });

  testWidgets('opened cold, a save lands on the accounts list instead of throwing on the pop', (WidgetTester tester) async {
    await pumpApp(tester, at: Routes.newAccount);

    await tester.enterText(field('Name'), 'Ví tiền mặt');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AccountsPage), findsOneWidget);
    expect(find.text('Ví tiền mặt'), findsOneWidget);
  });

  testWidgets('edit keeps the currency fixed and saves the rest in place', (WidgetTester tester) async {
    await seedAccount('Ví đô', Money(1000, 'USD'));
    await pumpApp(tester, at: Routes.accounts);

    await tester.tap(find.text('Ví đô'));
    await settleRead(tester);

    expect(find.text('Edit account'), findsOneWidget);
    expect(find.text('The currency cannot change once the account exists.'), findsOneWidget);
    expect(tester.widget<TextField>(field('Opening balance')).controller!.text, '10.00');

    await tester.enterText(field('Name'), 'Ví USD');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountsPage), findsOneWidget);
    expect(find.text('Ví USD'), findsOneWidget);
    final stored = await tester.runAsync(() => repositories.accounts.watchAccounts().first);
    expect(stored!.single.initialBalance, Money(1000, 'USD'));
  });

  testWidgets('a blank name is refused under the name field, which takes the focus back', (WidgetTester tester) async {
    await pumpApp(tester, at: Routes.newAccount);
    await tester.tap(field('Opening balance'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(errorOn(tester, 'Name'), "Account name can't be empty.");
    expect(tester.widget<TextField>(field('Name')).focusNode!.hasFocus, isTrue);
    expect(find.byType(GPFormFailureBanner), findsNothing);
    expect(find.byType(AccountFormPage), findsOneWidget);
  });

  testWidgets('a conflict on edit owns no field, so it is the banner', (WidgetTester tester) async {
    await seedAccount('Ví', Money(0, 'VND'));
    await pumpApp(tester, at: Routes.accounts);
    await tester.tap(find.text('Ví'));
    await settleRead(tester);
    await tester.runAsync(() => repositories.db.customStatement('UPDATE accounts SET version = version + 1'));

    await tester.enterText(field('Name'), 'Ví mới');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settleRead(tester);

    expect(find.widgetWithText(GPFormFailureBanner, 'This item was changed on another device.'), findsOneWidget);
    expect(errorOn(tester, 'Name'), isNull);
  });
}
