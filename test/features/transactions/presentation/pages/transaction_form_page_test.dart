import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/app.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/app/router/app_shell.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/failure_message.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/core/widgets/form_failure_banner.dart';
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

/// The whole app over the real repositories: the form's job is done only when the list it pops back to shows the row.
void main() {
  late InMemoryRepositories repositories;

  setUpAll(initializeDateFormatting);

  setUp(() {
    repositories = InMemoryRepositories(clock: FakeClock(DateTime(2026, 10, 12, 9, 30).toUtc()));
    getIt
      ..registerSingleton<AccountRepository>(repositories.accounts)
      ..registerSingleton<CategoryRepository>(repositories.categories)
      ..registerSingleton<TransactionRepository>(repositories.transactions)
      ..registerSingleton<GPClock>(repositories.clock);
  });

  tearDown(() async {
    await getIt.reset();
    await repositories.close();
  });

  Future<void> pumpApp(WidgetTester tester, {String at = Routes.transactions}) async {
    await tester.pumpWidget(GPApp(initialLocation: at, localization: await localizationFor(GPLocale.en)));
    await tester.pumpAndSettle();
  }

  /// For a one-shot read (`.first`), as the edit form's load is: the database was opened outside the fake zone, so its future completes only in real time.
  Future<void> settleRead(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();
  }

  /// Cold on the edit form, whose load would keep a plain settle spinning.
  Future<void> pumpEditForm(WidgetTester tester, String transactionId) async {
    await tester.pumpWidget(GPApp(initialLocation: '/transactions/$transactionId/edit', localization: await localizationFor(GPLocale.en)));
    await settleRead(tester);
  }

  Future<void> openRow(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await settleRead(tester);
  }

  Future<void> openForm(WidgetTester tester) async {
    await tester.tap(find.byKey(AppShell.addButtonKey));
    await tester.pumpAndSettle();
  }

  Future<AccountEntity> seedAccount(String name) async =>
      (await repositories.accounts.createAccount(name: name, type: AccountType.cash, initialBalance: Money(0, 'VND')) as GPOk<AccountEntity>).value;

  Future<TransactionEntity> seedExpense(AccountEntity on, {String note = 'Phở bò', DateTime? at}) async =>
      (await repositories.transactions.createTransaction(
                type: TransactionType.expense,
                accountId: on.id,
                amount: Money(45000, 'VND'),
                occurredAt: at ?? repositories.clock.nowUtc(),
                note: note,
              )
              as GPOk<TransactionEntity>)
          .value;

  Finder field(String label) => find.widgetWithText(TextField, label);

  testWidgets('with no account, adds one from the empty state and comes back to the form with it chosen', (WidgetTester tester) async {
    await pumpApp(tester);
    await openForm(tester);

    expect(find.text('Add an account first'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountFormPage), findsOneWidget);

    await tester.enterText(field('Name'), 'Ví tiền mặt');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(TransactionFormPage), findsOneWidget);
    expect(field('Amount'), findsOneWidget);
    expect(find.text('Ví tiền mặt'), findsOneWidget);
  });

  testWidgets('saves an expense and pops back to the list, which shows it with no refresh', (WidgetTester tester) async {
    await seedAccount('Ví tiền mặt');
    await pumpApp(tester);
    await openForm(tester);

    await tester.enterText(field('Amount'), '45000');
    await tester.enterText(field('Note'), 'Phở bò');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(TransactionsPage), findsOneWidget);
    expect(find.text('Phở bò'), findsOneWidget);
    expect(find.text('-₫45,000'), findsOneWidget);
  });

  testWidgets('a refused save stays on the form and says why under the field it is about, with focus moved there', (WidgetTester tester) async {
    await seedAccount('Ví tiền mặt');
    await pumpApp(tester);
    await openForm(tester);
    // Somewhere else first, so the focus has to move.
    await tester.tap(field('Note'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(TransactionFormPage), findsOneWidget);
    final amount = tester.widget<TextField>(field('Amount'));
    expect(amount.decoration!.errorText, 'Amount must be greater than zero.');
    expect(amount.focusNode!.hasFocus, isTrue);
    expect(find.byType(GPFormFailureBanner), findsNothing, reason: 'a failure a field owns is shown once, on that field');

    await tester.enterText(field('Amount'), '45000');
    await tester.pump();
    expect(tester.widget<TextField>(field('Amount')).decoration!.errorText, isNull);
    // Outside the fake zone: a drift stream's first read waits on a real timer.
    final stored = await tester.runAsync(() => repositories.transactions.watchTransactions(TransactionQuery(limit: 1)).first);
    expect(stored!.transactions, isEmpty);
  });

  testWidgets('an income is offered income categories only', (WidgetTester tester) async {
    await seedAccount('Ví tiền mặt');
    await repositories.categories.createCategory(name: 'Ăn uống', type: CategoryType.expense);
    await repositories.categories.createCategory(name: 'Lương', type: CategoryType.income);
    await pumpApp(tester);
    await openForm(tester);

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uncategorised'));
    await tester.pumpAndSettle();

    expect(find.text('Lương'), findsWidgets);
    expect(find.text('Ăn uống'), findsNothing);
  });

  testWidgets('opened cold, with no page under it, a save lands on the list instead of throwing on the pop', (WidgetTester tester) async {
    await seedAccount('Ví tiền mặt');
    await pumpApp(tester, at: Routes.newTransaction);

    await tester.enterText(field('Amount'), '45000');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TransactionsPage), findsOneWidget);
  });

  testWidgets('accounts that cannot be read show the failure, not an endless spinner', (WidgetTester tester) async {
    getIt
      ..unregister<AccountRepository>()
      ..registerSingleton<AccountRepository>(FakeAccountRepository(accounts: Stream<List<AccountEntity>>.error(const GPDatabaseFailure())));
    await pumpApp(tester, at: Routes.newTransaction);

    expect(find.text('Could not read local data.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('dragging the form puts the keyboard away', (WidgetTester tester) async {
    // Short enough that the form scrolls, as it does on a phone with the keyboard up.
    tester.view
      ..physicalSize = const Size(400, 420)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seedAccount('Ví tiền mặt');
    await pumpApp(tester, at: Routes.newTransaction);
    expect(tester.testTextInput.isVisible, isTrue, reason: 'the amount field takes focus on open');

    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pumpAndSettle();

    expect(tester.testTextInput.isVisible, isFalse);
  });

  group('edit', () {
    testWidgets('a row opens in the form, filled in and with no keyboard; a save pops back with the change', (WidgetTester tester) async {
      await seedExpense(await seedAccount('Ví tiền mặt'));
      await pumpApp(tester);

      await openRow(tester, 'Phở bò');

      expect(find.byType(TransactionFormPage), findsOneWidget);
      expect(find.text('Edit transaction'), findsOneWidget);
      expect(find.text('45,000'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse, reason: 'an edit opens on what is there');

      await tester.enterText(field('Note'), 'Bún chả');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.byType(TransactionsPage), findsOneWidget);
      expect(find.text('Bún chả'), findsOneWidget);
      expect(find.text('Phở bò'), findsNothing);
    });

    testWidgets('the date field shows the day the transaction has, not today', (WidgetTester tester) async {
      await seedExpense(await seedAccount('Ví tiền mặt'), at: repositories.clock.nowUtc().subtract(const Duration(days: 1)));
      await pumpApp(tester);

      await openRow(tester, 'Phở bò');

      expect(find.widgetWithText(InputDecorator, 'Yesterday'), findsOneWidget);
    });

    testWidgets('a transfer row does not open: the form has no destination field yet', (WidgetTester tester) async {
      final cash = await seedAccount('Ví tiền mặt');
      final bank = await seedAccount('Ngân hàng');
      await repositories.transactions.createTransaction(
        type: TransactionType.transfer,
        accountId: cash.id,
        destinationAccountId: bank.id,
        amount: Money(100000, 'VND'),
        occurredAt: repositories.clock.nowUtc(),
        note: 'Chuyển',
      );
      await pumpApp(tester);

      await tester.tap(find.text('Chuyển'));
      await tester.pumpAndSettle();

      expect(find.byType(TransactionFormPage), findsNothing);
    });

    testWidgets('opened cold on a transaction that is gone, says so and offers no delete', (WidgetTester tester) async {
      await seedAccount('Ví tiền mặt');
      await pumpEditForm(tester, 'tx-missing');

      expect(find.text(const GPNotFoundFailure().message(const GPLocaleEn())), findsOneWidget);
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.delete_outline)).onPressed, isNull);
    });
  });

  group('delete and undo', () {
    Future<void> settleSnackBar(WidgetTester tester) async {
      // The write runs between frames, so settle once for the row and once more for the snackbar it sets off.
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
    }

    Finder dialogButton(String label) => find.descendant(of: find.byType(AlertDialog), matching: find.text(label));

    /// Swipes the row and confirms in the dialog the swipe opens.
    Future<void> swipeAway(WidgetTester tester, String row) async {
      await tester.drag(find.text(row), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Delete'));
      await settleSnackBar(tester);
    }

    testWidgets('deleting from the form pops to the list, which offers the undo; undo brings it back', (WidgetTester tester) async {
      await seedExpense(await seedAccount('Ví tiền mặt'));
      await pumpApp(tester);
      await openRow(tester, 'Phở bò');

      await tester.tap(find.byTooltip('Delete'));
      await settleSnackBar(tester);

      expect(find.byType(TransactionsPage), findsOneWidget);
      expect(find.text('Phở bò'), findsNothing);
      expect(find.text('Transaction deleted'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settleSnackBar(tester);

      expect(find.text('Phở bò'), findsOneWidget);
    });

    testWidgets('swiping a row away deletes it and offers the undo above the dock', (WidgetTester tester) async {
      await seedExpense(await seedAccount('Ví tiền mặt'));
      await pumpApp(tester);

      await swipeAway(tester, 'Phở bò');

      expect(find.text('Phở bò'), findsNothing);
      expect(find.text('Transaction deleted'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'the row leaves the tree before the dismissed row would be rebuilt');
      // The Material, not the SnackBar: the widget's own box includes the inset that lifts it.
      final snackBar = tester.getRect(find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first);
      expect(snackBar.bottom, lessThanOrEqualTo(tester.getRect(find.byKey(AppShell.dockKey)).top));

      await tester.tap(find.text('Undo'));
      await settleSnackBar(tester);

      expect(find.text('Phở bò'), findsOneWidget);
    });

    testWidgets('a swipe asks first, naming the row; Cancel puts the row back and writes nothing', (WidgetTester tester) async {
      await seedExpense(await seedAccount('Ví tiền mặt'));
      await pumpApp(tester);

      await tester.drag(find.text('Phở bò'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Delete this transaction?'), findsOneWidget);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Phở bò')), findsOneWidget);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('-₫45,000')), findsOneWidget);

      await tester.tap(dialogButton('Cancel'));
      await settleSnackBar(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Phở bò'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Phở bò')).dx, lessThan(100), reason: 'slid back into place, not left half off the card');
      expect(find.text('Transaction deleted'), findsNothing);
      final stored = await tester.runAsync(() => repositories.transactions.watchTransactions(TransactionQuery(limit: 1)).first);
      expect(stored!.transactions, hasLength(1));
    });

    testWidgets('tapping outside the dialog keeps the row too', (WidgetTester tester) async {
      await seedExpense(await seedAccount('Ví tiền mặt'));
      await pumpApp(tester);

      await tester.drag(find.text('Phở bò'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await settleSnackBar(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Phở bò'), findsOneWidget);
      expect(find.text('Transaction deleted'), findsNothing);
    });

    testWidgets("a second delete replaces the first one's snackbar, so Undo takes back the latest", (WidgetTester tester) async {
      final cash = await seedAccount('Ví tiền mặt');
      await seedExpense(cash);
      await seedExpense(cash, note: 'Bún chả');
      await pumpApp(tester);

      await swipeAway(tester, 'Phở bò');
      await swipeAway(tester, 'Bún chả');
      await tester.tap(find.text('Undo'));
      await settleSnackBar(tester);

      expect(find.text('Bún chả'), findsOneWidget);
      expect(find.text('Phở bò'), findsNothing);
    });

    testWidgets("a screen reader deletes through the row's own action", (WidgetTester tester) async {
      final semantics = tester.ensureSemantics();
      final cash = await seedAccount('Ví tiền mặt');
      await seedExpense(cash);
      await seedExpense(cash, note: 'Bún chả');
      await pumpApp(tester);
      const delete = CustomSemanticsAction(label: 'Delete');

      final row = tester.getSemantics(find.text('Phở bò'));
      expect(row.id, isNot(tester.getSemantics(find.text('Bún chả')).id), reason: 'each row is a node of its own, so the action names one row');
      expect(row.getSemanticsData().customSemanticsActionIds, contains(CustomSemanticsAction.getIdentifier(delete)));
      row.owner!.performAction(row.id, SemanticsAction.customAction, CustomSemanticsAction.getIdentifier(delete));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'the action is the swipe, so it asks too');
      await tester.tap(dialogButton('Delete'));
      await settleSnackBar(tester);

      expect(find.text('Phở bò'), findsNothing);
      expect(find.text('Bún chả'), findsOneWidget, reason: 'the action names its own row, not the card');
      expect(find.text('Transaction deleted'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('an undo refused because the account went meanwhile says why, and the row stays gone', (WidgetTester tester) async {
      final cash = await seedAccount('Ví tiền mặt');
      await seedExpense(cash);
      await pumpApp(tester);
      await swipeAway(tester, 'Phở bò');

      await repositories.accounts.deleteAccount(cash.id);
      await tester.tap(find.text('Undo'));
      await settleSnackBar(tester);

      expect(find.text(const GPNotFoundFailure().message(const GPLocaleEn())), findsOneWidget);
      expect(find.text('Phở bò'), findsNothing);
    });

    testWidgets('opened cold, a delete lands on the list instead of throwing on the pop', (WidgetTester tester) async {
      final transaction = await seedExpense(await seedAccount('Ví tiền mặt'));
      await pumpEditForm(tester, transaction.id);

      await tester.tap(find.byTooltip('Delete'));
      await settleSnackBar(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(TransactionsPage), findsOneWidget);
      expect(find.text('Phở bò'), findsNothing);
    });
  });
}
