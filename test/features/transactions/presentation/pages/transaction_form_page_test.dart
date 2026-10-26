import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/app.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/app/router/app_shell.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/failure_extension.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/core/widgets/date_picker.dart';
import 'package:ghpockit/core/widgets/dialog.dart';
import 'package:ghpockit/core/widgets/field.dart';
import 'package:ghpockit/core/widgets/form_failure_banner.dart';
import 'package:ghpockit/core/widgets/select.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/accounts/presentation/pages/account_form_page.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/categories/domain/repositories/category_repository.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:ghpockit/features/transactions/presentation/pages/transaction_form_page.dart';
import 'package:ghpockit/features/transactions/presentation/pages/transactions_page.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../helpers/fake_account_repository.dart';
import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/in_memory_repositories.dart';
import '../../../../helpers/localization_harness.dart';
import '../../../../helpers/results.dart';

/// The whole app over the real _repositories: the form's job is done only when the list it pops back to shows the row.
late InMemoryRepositories _repositories;

void main() {
  setUpAll(initializeDateFormatting);

  setUp(() {
    _repositories = InMemoryRepositories(FakeClock(DateTime(2026, 10, 12, 9, 30).toUtc()));
    getIt
      ..registerSingleton<AccountRepository>(_repositories.accounts)
      ..registerSingleton<CategoryRepository>(_repositories.categories)
      ..registerSingleton<TransactionRepository>(_repositories.transactions)
      ..registerSingleton<GPClock>(_repositories.clock);
  });

  tearDown(() async {
    await getIt.reset();
    await _repositories.close();
  });

  testWidgets('with no account, adds one from the empty state and comes back to the form with it chosen', (tester) async {
    await _pumpApp(tester);
    await _openForm(tester);

    expect(find.text('Add an account first'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountFormPage), findsOneWidget);

    await tester.enterText(_field('Name'), 'Ví tiền mặt');
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(find.byType(TransactionFormPage), findsOneWidget);
    expect(_field('Amount'), findsOneWidget);
    expect(find.text('Ví tiền mặt'), findsOneWidget);
  });

  testWidgets('saves an expense and pops back to the list, which shows it with no refresh', (tester) async {
    await _seedAccount('Ví tiền mặt');
    await _pumpApp(tester);
    await _openForm(tester);

    await tester.enterText(_field('Amount'), '45000');
    await tester.enterText(_field('Note'), 'Phở bò');
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(find.byType(TransactionsPage), findsOneWidget);
    expect(find.text('Phở bò'), findsOneWidget);
    expect(find.text('-₫45,000'), findsOneWidget);
  });

  testWidgets('a refused save stays on the form and says why under the field it is about, with focus moved there', (tester) async {
    await _seedAccount('Ví tiền mặt');
    await _pumpApp(tester);
    await _openForm(tester);
    // Somewhere else first, so the focus has to move.
    await tester.tap(_field('Note'));
    await tester.pumpAndSettle();

    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(find.byType(TransactionFormPage), findsOneWidget);
    expect(_errorOn(tester, 'Amount'), 'Amount must be greater than zero.');
    expect(tester.widget<TextField>(_field('Amount')).focusNode!.hasFocus, isTrue);
    expect(find.byType(GPFormFailureBanner), findsNothing, reason: 'a failure a field owns is shown once, on that field');

    await tester.enterText(_field('Amount'), '45000');
    await tester.pump();
    expect(_errorOn(tester, 'Amount'), isNull);
    // Outside the fake zone: a drift stream's first read waits on a real timer.
    final stored = await tester.runAsync(() => _repositories.transactions.watchTransactions(TransactionQuery(limit: 1)).first);
    expect(stored!.transactions, isEmpty);
  });

  testWidgets('an income is offered income categories only', (tester) async {
    await _seedAccount('Ví tiền mặt');
    await _repositories.categories.createCategory(type: CategoryType.expense, name: 'Ăn uống');
    await _repositories.categories.createCategory(type: CategoryType.income, name: 'Lương');
    await _pumpApp(tester);
    await _openForm(tester);

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uncategorised'));
    await tester.pumpAndSettle();

    expect(find.text('Lương'), findsWidgets);
    expect(find.text('Ăn uống'), findsNothing);
  });

  testWidgets('opened cold, with no page under it, a save lands on the list instead of throwing on the pop', (tester) async {
    await _seedAccount('Ví tiền mặt');
    await _pumpApp(tester, at: Routes.newTransaction);

    await tester.enterText(_field('Amount'), '45000');
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TransactionsPage), findsOneWidget);
  });

  testWidgets('accounts that cannot be read show the failure, not an endless spinner', (tester) async {
    getIt
      ..unregister<AccountRepository>()
      ..registerSingleton<AccountRepository>(FakeAccountRepository(Stream.error(const GPDatabaseFailure())));
    await _pumpApp(tester, at: Routes.newTransaction);

    expect(find.text('Could not read local data.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('dragging the form puts the keyboard away', (tester) async {
    // Short enough that the form scrolls, as it does on a phone with the keyboard up.
    tester.view
      ..physicalSize = const Size(400.0, 420.0)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _seedAccount('Ví tiền mặt');
    await _pumpApp(tester, at: Routes.newTransaction);
    expect(tester.testTextInput.isVisible, isTrue, reason: 'the amount field takes focus on open');

    await tester.drag(find.byType(ListView), const Offset(0.0, -150.0));
    await tester.pumpAndSettle();

    expect(tester.testTextInput.isVisible, isFalse);
  });

  group('edit', () {
    testWidgets('a row opens in the form, filled in and with no keyboard; a save pops back with the change', (tester) async {
      await _seedExpense(await _seedAccount('Ví tiền mặt'));
      await _pumpApp(tester);

      await _openRow(tester, 'Phở bò');

      expect(find.byType(TransactionFormPage), findsOneWidget);
      expect(find.text('Edit transaction'), findsOneWidget);
      expect(find.text('45,000'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse, reason: 'an edit opens on what is there');

      await tester.enterText(_field('Note'), 'Bún chả');
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.byType(TransactionsPage), findsOneWidget);
      expect(find.text('Bún chả'), findsOneWidget);
      expect(find.text('Phở bò'), findsNothing);
    });

    testWidgets('the date field shows the day the transaction has, not today', (tester) async {
      await _seedExpense(await _seedAccount('Ví tiền mặt'), at: _repositories.clock.nowUtc().subtract(const Duration(days: 1)));
      await _pumpApp(tester);

      await _openRow(tester, 'Phở bò');

      expect(find.widgetWithText(GPDateField, 'Yesterday'), findsOneWidget);
    });

    testWidgets('a transfer row opens with both accounts and no category', (tester) async {
      final cash = await _seedAccount('Ví tiền mặt');
      final bank = await _seedAccount('Ngân hàng');
      await _repositories.transactions.createTransaction(
        amount: Money(100000, 'VND'),
        type: TransactionType.transfer,
        occurredAt: _repositories.clock.nowUtc(),
        accountId: cash.id,
        destinationAccountId: bank.id,
        note: 'Chuyển',
      );
      await _pumpApp(tester);

      await _openRow(tester, 'Chuyển');

      expect(find.byType(TransactionFormPage), findsOneWidget);
      expect(find.widgetWithText(GPSelect<String>, 'Ví tiền mặt'), findsOneWidget);
      expect(find.widgetWithText(GPSelect<String>, 'Ngân hàng'), findsOneWidget);
      expect(find.text('Category'), findsNothing);
    });

    testWidgets('opened cold on a transaction that is gone, says so and offers no delete', (tester) async {
      await _seedAccount('Ví tiền mặt');
      await _pumpEditForm(tester, 'tx-missing');

      expect(find.text(const GPNotFoundFailure().getMessage(const GPLocaleEn())), findsOneWidget);
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.delete_outline)).onPressed, isNull);
    });
  });

  group('delete and undo', () {
    testWidgets('deleting from the form pops to the list, which offers the undo; undo brings it back', (tester) async {
      await _seedExpense(await _seedAccount('Ví tiền mặt'));
      await _pumpApp(tester);
      await _openRow(tester, 'Phở bò');

      await tester.tap(find.byTooltip('Delete'));
      await _settleSnackBar(tester);

      expect(find.byType(TransactionsPage), findsOneWidget);
      expect(find.text('Phở bò'), findsNothing);
      expect(find.text('Transaction deleted'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await _settleSnackBar(tester);

      expect(find.text('Phở bò'), findsOneWidget);
    });

    testWidgets('swiping a row away deletes it and offers the undo above the dock', (tester) async {
      await _seedExpense(await _seedAccount('Ví tiền mặt'));
      await _pumpApp(tester);

      await _swipeAway(tester, 'Phở bò');

      expect(find.text('Phở bò'), findsNothing);
      expect(find.text('Transaction deleted'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'the row leaves the tree before the dismissed row would be rebuilt');
      // The Material, not the SnackBar: the widget's own box includes the inset that lifts it.
      final snackBar = tester.getRect(find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first);
      expect(snackBar.bottom, lessThanOrEqualTo(tester.getRect(find.byKey(AppShell.dockKey)).top));

      await tester.tap(find.text('Undo'));
      await _settleSnackBar(tester);

      expect(find.text('Phở bò'), findsOneWidget);
    });

    testWidgets('a swipe asks first, naming the row; Cancel puts the row back and writes nothing', (tester) async {
      await _seedExpense(await _seedAccount('Ví tiền mặt'));
      await _pumpApp(tester);

      await tester.drag(find.text('Phở bò'), const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();

      expect(find.text('Delete this transaction?'), findsOneWidget);
      expect(find.descendant(of: find.byType(GPDialog<bool>), matching: find.text('Phở bò')), findsOneWidget);
      expect(find.descendant(of: find.byType(GPDialog<bool>), matching: find.text('-₫45,000')), findsOneWidget);

      await tester.tap(_dialogButton('Cancel'));
      await _settleSnackBar(tester);

      expect(find.byType(GPDialog<bool>), findsNothing);
      expect(find.text('Phở bò'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Phở bò')).dx, lessThan(100), reason: 'slid back into place, not left half off the card');
      expect(find.text('Transaction deleted'), findsNothing);
      final stored = await tester.runAsync(() => _repositories.transactions.watchTransactions(TransactionQuery(limit: 1)).first);
      expect(stored!.transactions, hasLength(1));
    });

    testWidgets('tapping outside the dialog keeps the row too', (tester) async {
      await _seedExpense(await _seedAccount('Ví tiền mặt'));
      await _pumpApp(tester);

      await tester.drag(find.text('Phở bò'), const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10.0, 10.0));
      await _settleSnackBar(tester);

      expect(find.byType(GPDialog<bool>), findsNothing);
      expect(find.text('Phở bò'), findsOneWidget);
      expect(find.text('Transaction deleted'), findsNothing);
    });

    testWidgets("a second delete replaces the first one's snackbar, so Undo takes back the latest", (tester) async {
      final cash = await _seedAccount('Ví tiền mặt');
      await _seedExpense(cash);
      await _seedExpense(cash, note: 'Bún chả');
      await _pumpApp(tester);

      await _swipeAway(tester, 'Phở bò');
      await _swipeAway(tester, 'Bún chả');
      await tester.tap(find.text('Undo'));
      await _settleSnackBar(tester);

      expect(find.text('Bún chả'), findsOneWidget);
      expect(find.text('Phở bò'), findsNothing);
    });

    testWidgets("a screen reader deletes through the row's own action", (tester) async {
      final semantics = tester.ensureSemantics();
      final cash = await _seedAccount('Ví tiền mặt');
      await _seedExpense(cash);
      await _seedExpense(cash, note: 'Bún chả');
      await _pumpApp(tester);
      const delete = CustomSemanticsAction(label: 'Delete');

      final row = tester.getSemantics(find.text('Phở bò'));
      expect(row.id, isNot(tester.getSemantics(find.text('Bún chả')).id), reason: 'each row is a node of its own, so the action names one row');
      expect(row.getSemanticsData().customSemanticsActionIds, contains(CustomSemanticsAction.getIdentifier(delete)));
      row.owner!.performAction(row.id, SemanticsAction.customAction, CustomSemanticsAction.getIdentifier(delete));
      await tester.pumpAndSettle();
      expect(find.byType(GPDialog<bool>), findsOneWidget, reason: 'the action is the swipe, so it asks too');
      await tester.tap(_dialogButton('Delete'));
      await _settleSnackBar(tester);

      expect(find.text('Phở bò'), findsNothing);
      expect(find.text('Bún chả'), findsOneWidget, reason: 'the action names its own row, not the card');
      expect(find.text('Transaction deleted'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('an undo refused because the account went meanwhile says why, and the row stays gone', (tester) async {
      final cash = await _seedAccount('Ví tiền mặt');
      await _seedExpense(cash);
      await _pumpApp(tester);
      await _swipeAway(tester, 'Phở bò');

      await _repositories.accounts.deleteAccount(cash.id);
      await tester.tap(find.text('Undo'));
      await _settleSnackBar(tester);

      expect(find.text(const GPNotFoundFailure().getMessage(const GPLocaleEn())), findsOneWidget);
      expect(find.text('Phở bò'), findsNothing);
    });

    testWidgets('opened cold, a delete lands on the list instead of throwing on the pop', (tester) async {
      final transaction = await _seedExpense(await _seedAccount('Ví tiền mặt'));
      await _pumpEditForm(tester, transaction.id);

      await tester.tap(find.byTooltip('Delete'));
      await _settleSnackBar(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(TransactionsPage), findsOneWidget);
      expect(find.text('Phở bò'), findsNothing);
    });
  });

  group('transfer', () {
    testWidgets('a transfer is one row, saved from the form with both accounts', (tester) async {
      await _seedAccount('Ví tiền mặt');
      await _seedAccount('Ngân hàng');
      await _pumpApp(tester);
      await _openForm(tester);

      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();

      expect(find.text('From account'), findsOneWidget);
      expect(find.text('Category'), findsNothing, reason: 'a transfer has no category');

      await _pick(tester, field: 'To account', option: 'Ngân hàng');
      await tester.enterText(_field('Amount'), '100000');
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.byType(TransactionsPage), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);
      expect(find.text('₫100,000'), findsOneWidget, reason: 'neither in nor out: no sign');
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    });

    testWidgets('saving with no destination says so under the destination', (tester) async {
      await _seedAccount('Ví tiền mặt');
      await _seedAccount('Ngân hàng');
      await _pumpApp(tester);
      await _openForm(tester);
      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();

      await tester.enterText(_field('Amount'), '100000');
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(tester.widget<GPSelect<String>>(find.byType(GPSelect<String>).last).errorText, 'Choose an account to transfer to.');
      expect(find.byType(GPFormFailureBanner), findsNothing);
    });

    testWidgets('with no second account in the currency, the destination says why and offers to add one', (tester) async {
      await _seedAccount('Ví tiền mặt');
      await _pumpApp(tester);
      await _openForm(tester);

      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();

      expect(find.text('A transfer needs another account in the same currency.'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Add account'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountFormPage), findsOneWidget);

      await tester.enterText(_field('Name'), 'Ngân hàng');
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.byType(TransactionFormPage), findsOneWidget);
      expect(find.text('A transfer needs another account in the same currency.'), findsNothing);
      expect(find.text('To account'), findsOneWidget);
    });
  });
}

Future<void> _pumpApp(WidgetTester tester, {String at = Routes.transactions}) async {
  await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.en), initialLocation: at));
  await tester.pumpAndSettle();
}

/// For a one-shot read (`.first`), as the edit form's load is: the database was opened outside the fake zone, so its future completes only in real time.
Future<void> _settleRead(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  await tester.pumpAndSettle();
}

/// Cold on the edit form, whose load would keep a plain settle spinning.
Future<void> _pumpEditForm(WidgetTester tester, String transactionId) async {
  await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.en), initialLocation: '/transactions/$transactionId/edit'));
  await _settleRead(tester);
}

Future<void> _openRow(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await _settleRead(tester);
}

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.byKey(AppShell.addButtonKey));
  await tester.pumpAndSettle();
}

Future<AccountEntity> _seedAccount(String name) async => okValue(await _repositories.accounts.createAccount(initialBalance: Money(0, 'VND'), type: AccountType.cash, name: name));

Future<TransactionEntity> _seedExpense(AccountEntity on, {DateTime? at, String note = 'Phở bò'}) async => okValue(
  await _repositories.transactions.createTransaction(
    amount: Money(45000, 'VND'),
    type: TransactionType.expense,
    occurredAt: at ?? _repositories.clock.nowUtc(),
    accountId: on.id,
    note: note,
  ),
);

/// The label sits above the box, outside the `TextField`.
Finder _field(String label) => find.descendant(of: find.widgetWithText(GPField, label), matching: find.byType(TextField));

/// The form outgrows the test screen, and a ListView only builds what is near the viewport.
Future<void> _tapSave(WidgetTester tester) async {
  final save = find.widgetWithText(FilledButton, 'Save');
  // A frame for what was just typed, as a device always has one, before the drag scrolls the form.
  await tester.pump();
  await tester.dragUntilVisible(save, find.byType(ListView).last, const Offset(0.0, -200.0));
  await tester.tap(save);
}

Future<void> _settleSnackBar(WidgetTester tester) async {
  // The write runs between frames, so settle once for the row and once more for the snackbar it sets off.
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

Finder _dialogButton(String label) => find.descendant(of: find.byType(GPDialog<bool>), matching: find.text(label));

/// Swipes the row and confirms in the dialog the swipe opens.
Future<void> _swipeAway(WidgetTester tester, String row) async {
  await tester.drag(find.text(row), const Offset(-500.0, 0.0));
  await tester.pumpAndSettle();
  await tester.tap(_dialogButton('Delete'));
  await _settleSnackBar(tester);
}

Future<void> _pick(WidgetTester tester, {required String field, required String option}) async {
  await tester.tap(find.descendant(of: find.widgetWithText(GPField, field), matching: find.byType(GPFieldBox)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

String? _errorOn(WidgetTester tester, String label) => tester.widget<GPField>(find.widgetWithText(GPField, label)).errorText;
