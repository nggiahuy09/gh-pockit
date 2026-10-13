import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/categories/domain/repositories/category_repository.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_form_cubit.dart';

import '../../../../helpers/fake_account_repository.dart';
import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/in_memory_repositories.dart';

void main() {
  // Monday 12 October 2026, 09:30 local: every date below is local, so the test reads the same in any time zone.
  final now = DateTime(2026, 10, 12, 9, 30);

  late InMemoryRepositories repositories;

  setUp(() {
    repositories = InMemoryRepositories(clock: FakeClock(now.toUtc()));
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

  T ok<T>(GPResult<T> result) => (result as GPOk<T>).value;

  Future<AccountEntity> account(String name, {String currency = 'VND'}) async =>
      ok(await repositories.accounts.createAccount(name: name, type: AccountType.cash, initialBalance: Money(0, currency)));

  Future<CategoryEntity> category(String name, CategoryType type) async => ok(await repositories.categories.createCategory(name: name, type: type));

  Future<TransactionFormCubit> started() async {
    final form = TransactionFormCubit()..start();
    addTearDown(form.close);
    await pumpEventQueue();
    return form;
  }

  Future<List<TransactionEntity>> stored() async => (await repositories.transactions.watchTransactions(TransactionQuery(limit: 10)).first).transactions;

  // Saturday 10 October, 19:45 local: two days before the clock, so "keeps its date" and "now" cannot be confused.
  final eatenAt = DateTime(2026, 10, 10, 19, 45);

  Future<TransactionEntity> expense(AccountEntity on, {CategoryEntity? filedUnder, String? note = 'Phở'}) async => ok(
    await repositories.transactions.createTransaction(
      type: TransactionType.expense,
      accountId: on.id,
      categoryId: filedUnder?.id,
      amount: Money(45000, on.initialBalance.currencyCode),
      occurredAt: eatenAt.toUtc(),
      note: note,
    ),
  );

  Future<TransactionFormCubit> editing(String id) async {
    final form = TransactionFormCubit(transactionId: id)..start();
    addTearDown(form.close);
    await form.load();
    await pumpEventQueue();
    return form;
  }

  group('loading', () {
    test('is loading until both lists arrive, then defaults to the oldest account', () async {
      final cash = await account('Tiền mặt');
      await account('Ngân hàng');

      final form = TransactionFormCubit();
      addTearDown(form.close);
      expect(form.state.isLoading, isTrue);

      form.start();
      await pumpEventQueue();

      expect(form.state.isLoading, isFalse);
      expect(form.state.accountId, cash.id);
      expect(form.state.type, TransactionType.expense);
      expect(form.state.pickedDay, isNull, reason: 'no day picked: the save dates itself');
    });

    test('with no account, there is nothing selected and the list is empty, not loading', () async {
      final form = await started();

      expect(form.state.isLoading, isFalse);
      expect(form.state.accounts, isEmpty);
      expect(form.state.accountId, isNull);
    });

    test('an account created while the form is open becomes the default', () async {
      final form = await started();

      final cash = await account('Tiền mặt');
      await pumpEventQueue();

      expect(form.state.accountId, cash.id);
    });

    test('a failed account read is the state failure, and the form stays loading', () async {
      getIt
        ..unregister<AccountRepository>()
        ..registerSingleton<AccountRepository>(FakeAccountRepository(accounts: Stream<List<AccountEntity>>.error(const GPDatabaseFailure())));

      final form = await started();

      expect(form.state.failure, const GPDatabaseFailure());
      expect(form.state.isLoading, isTrue);
    });

    test('a selected account archived elsewhere falls back to the oldest one left', () async {
      final cash = await account('Tiền mặt');
      final bank = await account('Ngân hàng');
      final form = await started();
      form.accountChanged(bank.id);

      await repositories.accounts.archiveAccount(bank.id);
      await pumpEventQueue();

      expect(form.state.accountId, cash.id);
    });
  });

  group('categories', () {
    test('offers only the kind that matches the type', () async {
      await account('Tiền mặt');
      final food = await category('Ăn uống', CategoryType.expense);
      final salary = await category('Lương', CategoryType.income);
      final form = await started();

      expect(form.state.categoriesForType, <CategoryEntity>[food]);

      form.typeChanged(TransactionType.income);

      expect(form.state.categoriesForType, <CategoryEntity>[salary]);
    });

    test('switching the type drops a category of the other kind', () async {
      await account('Tiền mặt');
      final food = await category('Ăn uống', CategoryType.expense);
      final form = await started();

      form
        ..categoryChanged(food.id)
        ..typeChanged(TransactionType.income);

      expect(form.state.categoryId, isNull);
    });

    test('a selected category deleted elsewhere is dropped', () async {
      await account('Tiền mặt');
      final food = await category('Ăn uống', CategoryType.expense);
      final form = await started();
      form.categoryChanged(food.id);

      await repositories.categories.deleteCategory(food.id);
      await pumpEventQueue();

      expect(form.state.categoryId, isNull);
    });
  });

  group('stale picks', () {
    test('an account id no longer in the list is ignored, so the selection always names a live account', () async {
      final cash = await account('Tiền mặt');
      final form = await started();

      form.accountChanged('acc-gone');

      expect(form.state.accountId, cash.id);
    });

    test('a category the current type cannot use is ignored', () async {
      await account('Tiền mặt');
      final salary = await category('Lương', CategoryType.income);
      final form = await started();

      form.categoryChanged(salary.id);

      expect(form.state.categoryId, isNull);
    });
  });

  group('submit', () {
    test("writes in the account's currency, at the current time, and ends saved", () async {
      final wallet = await account('Ví đô', currency: 'USD');
      final food = await category('Ăn uống', CategoryType.expense);
      final form = await started();

      form
        ..amountChanged(1250)
        ..categoryChanged(food.id)
        ..noteChanged('Phở');
      await form.submit();

      expect(form.state.isSaved, isTrue);
      final transaction = (await stored()).single;
      expect(transaction.type, TransactionType.expense);
      expect(transaction.accountId, wallet.id);
      expect(transaction.categoryId, food.id);
      expect(transaction.amount, Money(1250, 'USD'));
      expect(transaction.note, 'Phở');
      expect(transaction.occurredAt, now.toUtc());
    });

    test('a backdated day keeps the time of day, so same-day entries stay in typing order', () async {
      await account('Tiền mặt');
      final form = await started();

      form
        ..amountChanged(45000)
        ..dateChanged(DateTime(2026, 10, 10, 23, 59));
      await form.submit();

      expect((await stored()).single.occurredAt, DateTime(2026, 10, 10, 9, 30).toUtc());
    });

    test("nothing typed is the entity's 'not positive', and nothing is written", () async {
      await account('Tiền mặt');
      final form = await started();

      await form.submit();

      expect(form.state.failure, const GPValidationFailure(GPValidationCode.transactionAmountNotPositive));
      expect(form.state.isSaving, isFalse);
      expect(await stored(), isEmpty);
    });

    test('with no account it does nothing', () async {
      final form = await started();
      form.amountChanged(45000);

      await form.submit();

      expect(form.state.isSaving, isFalse);
      expect(form.state.failure, isNull);
      expect(await stored(), isEmpty);
    });

    test('a form left open past midnight dates the save at the save, not on the day it opened', () async {
      await account('Tiền mặt');
      repositories.clock.advance(const Duration(hours: 14, minutes: 29)); // 23:59
      final form = await started();
      form.amountChanged(45000);

      repositories.clock.advance(const Duration(minutes: 2)); // 00:01 on the 13th
      await form.submit();

      expect((await stored()).single.occurredAt, DateTime(2026, 10, 13, 0, 1).toUtc());
    });

    test('switching to an account in another currency keeps the digits and saves them in that currency', () async {
      await account('Tiền mặt');
      final dollars = await account('Ví đô', currency: 'USD');
      final form = await started();

      form
        ..amountChanged(1250)
        ..accountChanged(dollars.id);
      await form.submit();

      expect((await stored()).single.amount, Money(1250, 'USD'));
    });

    test('two submits fired together write once: the first marks the form busy before it awaits', () async {
      await account('Tiền mặt');
      final form = await started();
      form.amountChanged(45000);

      await Future.wait(<Future<void>>[form.submit(), form.submit()]);

      expect(await stored(), hasLength(1));
    });

    test('a second submit after saving writes nothing more', () async {
      await account('Tiền mặt');
      final form = await started();
      form.amountChanged(45000);

      await form.submit();
      await form.submit();

      expect(await stored(), hasLength(1));
    });
  });

  group('edit', () {
    test('is loading until the transaction is read, then holds what it was saved with', () async {
      final cash = await account('Tiền mặt');
      final food = await category('Ăn uống', CategoryType.expense);
      final transaction = await expense(cash, filedUnder: food);

      final form = TransactionFormCubit(transactionId: transaction.id)..start();
      addTearDown(form.close);
      await pumpEventQueue();
      expect(form.state.isLoading, isTrue, reason: 'the lists are in, the transaction is not');

      await form.load();

      expect(form.isEditing, isTrue);
      expect(form.state.isLoading, isFalse);
      expect(form.state.original, transaction);
      expect(form.state.type, TransactionType.expense);
      expect(form.state.accountId, cash.id);
      expect(form.state.categoryId, food.id);
      expect(form.state.amountMinorUnits, 45000);
      expect(form.state.note, 'Phở');
      expect(form.state.pickedDay, isNull);
    });

    test('saves in place: the same id and date, with the fields changed', () async {
      final cash = await account('Tiền mặt');
      final transaction = await expense(cash);
      final form = await editing(transaction.id);

      form
        ..amountChanged(52000)
        ..noteChanged('Bún chả');
      await form.submit();

      expect(form.state.isSaved, isTrue);
      final saved = (await stored()).single;
      expect(saved.id, transaction.id);
      expect(saved.amount, Money(52000, 'VND'));
      expect(saved.note, 'Bún chả');
      expect(saved.occurredAt, eatenAt.toUtc(), reason: 'no day picked keeps the date, where a new one would take now');
    });

    test('a day picked keeps the time of day the transaction had', () async {
      final transaction = await expense(await account('Tiền mặt'));
      final form = await editing(transaction.id);

      form.dateChanged(DateTime(2026, 10, 8));
      await form.submit();

      expect((await stored()).single.occurredAt, DateTime(2026, 10, 8, 19, 45).toUtc());
    });

    test('the category and the note clear when the user clears them', () async {
      final cash = await account('Tiền mặt');
      final transaction = await expense(cash, filedUnder: await category('Ăn uống', CategoryType.expense));
      final form = await editing(transaction.id);

      form
        ..categoryChanged(null)
        ..noteChanged('');
      await form.submit();

      final saved = (await stored()).single;
      expect(saved.categoryId, isNull);
      expect(saved.note, isNull);
    });

    test('a category deleted since stays the filing, so fixing the note does not re-file it', () async {
      final cash = await account('Tiền mặt');
      final food = await category('Ăn uống', CategoryType.expense);
      final transaction = await expense(cash, filedUnder: food);
      await repositories.categories.deleteCategory(food.id);
      final form = await editing(transaction.id);
      // The list again, after the load: whichever arrives first, the filing must hold.
      await category('Cà phê', CategoryType.expense);
      await pumpEventQueue();

      expect(form.state.categoryId, food.id);
      expect(form.state.selectedCategory, isNull, reason: 'not on offer: the page shows it as uncategorised');

      form.noteChanged('Bún chả');
      await form.submit();

      expect(form.state.isSaved, isTrue);
      expect((await stored()).single.categoryId, food.id);
    });

    test('an account archived since stays the account, rather than the transaction moving to the oldest', () async {
      await account('Tiền mặt');
      final bank = await account('Ngân hàng');
      final transaction = await expense(bank);
      await repositories.accounts.archiveAccount(bank.id);
      final form = await editing(transaction.id);
      await account('Ví mới');
      await pumpEventQueue();

      expect(form.state.accountId, bank.id);
      expect(form.state.selectedAccount, isNull);
      expect(form.state.currencyCode, 'VND', reason: "the transaction's own, while its account is not on offer");

      form.noteChanged('Bún chả');
      await form.submit();

      expect((await stored()).single.accountId, bank.id);
    });

    test('a transaction that is gone loads as not found, and a submit then writes nothing', () async {
      await account('Tiền mặt');
      final form = await editing('tx-missing');

      expect(form.state.isLoading, isFalse);
      expect(form.state.original, isNull);
      expect(form.state.failure, const GPNotFoundFailure());

      form.amountChanged(45000);
      await form.submit();

      expect(form.state.isSaved, isFalse);
      expect(await stored(), isEmpty, reason: 'an edit with nothing loaded must not become a create');
    });

    test('a change made elsewhere after loading is a conflict, not an overwrite', () async {
      final transaction = await expense(await account('Tiền mặt'));
      final form = await editing(transaction.id);
      await repositories.db.customStatement('UPDATE transactions SET version = version + 1');

      form.noteChanged('Bún chả');
      await form.submit();

      expect(form.state.failure, isA<GPConflictFailure>());
      expect((await stored()).single.note, 'Phở');
    });
  });

  group('state', () {
    test('an edit that changes nothing emits nothing', () async {
      await account('Tiền mặt');
      final form = await started();
      form.noteChanged('Phở');
      final emitted = <TransactionFormState>[];
      final subscription = form.stream.listen(emitted.add);
      addTearDown(subscription.cancel);

      form.noteChanged('Phở');
      await pumpEventQueue();

      expect(emitted, isEmpty);
    });
  });

  group('a refused save', () {
    test('an amount refusal survives edits elsewhere and clears once the amount changes', () async {
      await account('Tiền mặt');
      final food = await category('Ăn uống', CategoryType.expense);
      final form = await started();
      await form.submit();
      const refused = GPValidationFailure(GPValidationCode.transactionAmountNotPositive);
      expect(form.state.failure, refused);

      form
        ..noteChanged('Phở')
        ..categoryChanged(food.id)
        ..dateChanged(DateTime(2026, 10, 11));
      expect(form.state.failure, refused, reason: 'none of those edits can fix the amount');

      form.amountChanged(45000);
      expect(form.state.failure, isNull);
    });

    test('a failure no field owns clears on any edit', () async {
      final accounts = StreamController<List<AccountEntity>>();
      addTearDown(accounts.close);
      getIt
        ..unregister<AccountRepository>()
        ..registerSingleton<AccountRepository>(FakeAccountRepository(accounts: accounts.stream));
      final cash =
          (AccountEntity.create(id: 'acc-cash', name: 'Tiền mặt', type: AccountType.cash, initialBalance: Money(0, 'VND'), createdAt: now, updatedAt: now) as GPOk<AccountEntity>)
              .value;
      final form = await started();
      accounts.add(<AccountEntity>[cash]);
      await pumpEventQueue();

      accounts.addError(const GPDatabaseFailure());
      await pumpEventQueue();
      expect(form.state.failure, const GPDatabaseFailure());

      form.noteChanged('Phở');
      expect(form.state.failure, isNull);
    });
  });
}
