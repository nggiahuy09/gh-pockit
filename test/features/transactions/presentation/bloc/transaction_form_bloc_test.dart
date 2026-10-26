import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
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
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_form_bloc.dart';
import 'package:ghpockit/features/transactions/presentation/transaction_form_field_enum.dart';

import '../../../../helpers/fake_account_repository.dart';
import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/in_memory_repositories.dart';
import '../../../../helpers/results.dart';

/// Monday 12 October 2026, 09:30 local: every date below is local, so the test reads the same in any time zone.
final _now = DateTime(2026, 10, 12, 9, 30);

/// Saturday 10 October, 19:45 local: two days before the clock, so "keeps its date" and "now" cannot be confused.
final _eatenAt = DateTime(2026, 10, 10, 19, 45);

late InMemoryRepositories _repositories;

void main() {
  setUp(() {
    _repositories = InMemoryRepositories(FakeClock(_now.toUtc()));
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

  group('loading', () {
    test('is loading until both lists arrive, then defaults to the oldest account', () async {
      final cash = await _account('Tiền mặt');
      await _account('Ngân hàng');

      final form = _form();
      expect(form.state.isLoading, isTrue);

      await pumpEventQueue();

      expect(form.state.isLoading, isFalse);
      expect(form.state.isEditing, isFalse);
      expect(form.state.accountId, cash.id);
      expect(form.state.type, TransactionType.expense);
      expect(form.state.pickedDay, isNull, reason: 'no day picked: the save dates itself');
    });

    test('with no account, there is nothing selected and the list is empty, not loading', () async {
      final form = await _started();

      expect(form.state.isLoading, isFalse);
      expect(form.state.accounts, isEmpty);
      expect(form.state.accountId, isNull);
    });

    test('an account created while the form is open becomes the default', () async {
      final form = await _started();

      final cash = await _account('Tiền mặt');
      await pumpEventQueue();

      expect(form.state.accountId, cash.id);
    });

    test('a failed account read is the state failure, and the form stays loading', () async {
      getIt
        ..unregister<AccountRepository>()
        ..registerSingleton<AccountRepository>(FakeAccountRepository(Stream.error(const GPDatabaseFailure())));

      final form = await _started();

      expect(form.state.failure, const GPDatabaseFailure());
      expect(form.state.isLoading, isTrue);
    });

    test('a selected account archived elsewhere falls back to the oldest one left', () async {
      final cash = await _account('Tiền mặt');
      final bank = await _account('Ngân hàng');
      final form = await _started();
      await _send([TransactionFormAccountChangeEvent(bank.id)], form);

      await _repositories.accounts.archiveAccount(bank.id);
      await pumpEventQueue();

      expect(form.state.accountId, cash.id);
    });
  });

  group('categories', () {
    test('offers only the kind that matches the type', () async {
      await _account('Tiền mặt');
      final food = await _category(CategoryType.expense, 'Ăn uống');
      final salary = await _category(CategoryType.income, 'Lương');
      final form = await _started();

      expect(form.state.categoriesForType, [food]);

      await _send([const TransactionFormTypeChangeEvent(TransactionType.income)], form);

      expect(form.state.categoriesForType, [salary]);
    });

    test('switching the type drops a category of the other kind', () async {
      await _account('Tiền mặt');
      final food = await _category(CategoryType.expense, 'Ăn uống');
      final form = await _started();

      await _send([TransactionFormCategoryChangeEvent(food.id), const TransactionFormTypeChangeEvent(TransactionType.income)], form);

      expect(form.state.categoryId, isNull);
    });

    test('a selected category deleted elsewhere is dropped', () async {
      await _account('Tiền mặt');
      final food = await _category(CategoryType.expense, 'Ăn uống');
      final form = await _started();
      await _send([TransactionFormCategoryChangeEvent(food.id)], form);

      await _repositories.categories.deleteCategory(food.id);
      await pumpEventQueue();

      expect(form.state.categoryId, isNull);
    });
  });

  group('stale picks', () {
    test('an account id no longer in the list is ignored, so the selection always names a live account', () async {
      final cash = await _account('Tiền mặt');
      final form = await _started();

      await _send([const TransactionFormAccountChangeEvent('acc-gone')], form);

      expect(form.state.accountId, cash.id);
    });

    test('a category the current type cannot use is ignored', () async {
      await _account('Tiền mặt');
      final salary = await _category(CategoryType.income, 'Lương');
      final form = await _started();

      await _send([TransactionFormCategoryChangeEvent(salary.id)], form);

      expect(form.state.categoryId, isNull);
    });
  });

  group('submit', () {
    test("writes in the account's currency, at the current time, and ends saved", () async {
      final wallet = await _account('Ví đô', currency: 'USD');
      final food = await _category(CategoryType.expense, 'Ăn uống');
      final form = await _started();

      await _send([
        const TransactionFormAmountChangeEvent(1250),
        TransactionFormCategoryChangeEvent(food.id),
        const TransactionFormNoteChangeEvent('Phở'),
        const TransactionFormSubmitEvent(),
      ], form);

      expect(form.state.isSaved, isTrue);
      final transaction = (await _stored()).single;
      expect(transaction.type, TransactionType.expense);
      expect(transaction.accountId, wallet.id);
      expect(transaction.categoryId, food.id);
      expect(transaction.amount, Money(1250, 'USD'));
      expect(transaction.note, 'Phở');
      expect(transaction.occurredAt, _now.toUtc());
    });

    test('a backdated day keeps the time of day, so same-day entries stay in typing order', () async {
      await _account('Tiền mặt');
      final form = await _started();

      await _send([const TransactionFormAmountChangeEvent(45000), TransactionFormDateChangeEvent(DateTime(2026, 10, 10, 23, 59)), const TransactionFormSubmitEvent()], form);

      expect((await _stored()).single.occurredAt, DateTime(2026, 10, 10, 9, 30).toUtc());
    });

    test("nothing typed is the entity's 'not positive', and nothing is written", () async {
      await _account('Tiền mặt');
      final form = await _started();

      await _send([const TransactionFormSubmitEvent()], form);

      expect(form.state.failure, const GPValidationFailure(GPValidationCode.transactionAmountNotPositive));
      expect(form.state.isSaving, isFalse);
      expect(await _stored(), isEmpty);
    });

    test('with no account it does nothing', () async {
      final form = await _started();

      await _send([const TransactionFormAmountChangeEvent(45000), const TransactionFormSubmitEvent()], form);

      expect(form.state.isSaving, isFalse);
      expect(form.state.failure, isNull);
      expect(await _stored(), isEmpty);
    });

    test('a form left open past midnight dates the save at the save, not on the day it opened', () async {
      await _account('Tiền mặt');
      _repositories.clock.advance(const Duration(hours: 14, minutes: 29)); // 23:59
      final form = await _started();
      await _send([const TransactionFormAmountChangeEvent(45000)], form);

      _repositories.clock.advance(const Duration(minutes: 2)); // 00:01 on the 13th
      await _send([const TransactionFormSubmitEvent()], form);

      expect((await _stored()).single.occurredAt, DateTime(2026, 10, 13, 0, 1).toUtc());
    });

    test('switching to an account in another currency keeps the digits and saves them in that currency', () async {
      await _account('Tiền mặt');
      final dollars = await _account('Ví đô', currency: 'USD');
      final form = await _started();

      await _send([const TransactionFormAmountChangeEvent(1250), TransactionFormAccountChangeEvent(dollars.id), const TransactionFormSubmitEvent()], form);

      expect((await _stored()).single.amount, Money(1250, 'USD'));
    });

    test('two submits sent together write once: the second meets a saved form', () async {
      await _account('Tiền mặt');
      final form = await _started();

      await _send([const TransactionFormAmountChangeEvent(45000), const TransactionFormSubmitEvent(), const TransactionFormSubmitEvent()], form);

      expect(await _stored(), hasLength(1));
    });

    test('a second submit after saving writes nothing more', () async {
      await _account('Tiền mặt');
      final form = await _started();

      await _send([const TransactionFormAmountChangeEvent(45000), const TransactionFormSubmitEvent()], form);
      await _send([const TransactionFormSubmitEvent()], form);

      expect(await _stored(), hasLength(1));
    });
  });

  group('edit', () {
    test('is loading until the transaction is read, then holds what it was saved with', () async {
      final cash = await _account('Tiền mặt');
      final food = await _category(CategoryType.expense, 'Ăn uống');
      final transaction = await _expense(cash, filedUnder: food);

      final form = _form(transaction.id);
      expect(form.state.isLoading, isTrue);
      expect(form.state.status, TransactionFormStatus.loading);

      await pumpEventQueue();

      expect(form.state.isEditing, isTrue);
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
      final cash = await _account('Tiền mặt');
      final transaction = await _expense(cash);
      final form = await _started(transaction.id);

      await _send([const TransactionFormAmountChangeEvent(52000), const TransactionFormNoteChangeEvent('Bún chả'), const TransactionFormSubmitEvent()], form);

      expect(form.state.isSaved, isTrue);
      final saved = (await _stored()).single;
      expect(saved.id, transaction.id);
      expect(saved.amount, Money(52000, 'VND'));
      expect(saved.note, 'Bún chả');
      expect(saved.occurredAt, _eatenAt.toUtc(), reason: 'no day picked keeps the date, where a new one would take now');
    });

    test('a day picked keeps the time of day the transaction had', () async {
      final transaction = await _expense(await _account('Tiền mặt'));
      final form = await _started(transaction.id);

      await _send([TransactionFormDateChangeEvent(DateTime(2026, 10, 8)), const TransactionFormSubmitEvent()], form);

      expect((await _stored()).single.occurredAt, DateTime(2026, 10, 8, 19, 45).toUtc());
    });

    test('the category and the note clear when the user clears them', () async {
      final cash = await _account('Tiền mặt');
      final transaction = await _expense(cash, filedUnder: await _category(CategoryType.expense, 'Ăn uống'));
      final form = await _started(transaction.id);

      await _send([const TransactionFormCategoryChangeEvent(null), const TransactionFormNoteChangeEvent(''), const TransactionFormSubmitEvent()], form);

      final saved = (await _stored()).single;
      expect(saved.categoryId, isNull);
      expect(saved.note, isNull);
    });

    test('a category deleted since stays the filing, so fixing the note does not re-file it', () async {
      final cash = await _account('Tiền mặt');
      final food = await _category(CategoryType.expense, 'Ăn uống');
      final transaction = await _expense(cash, filedUnder: food);
      await _repositories.categories.deleteCategory(food.id);
      final form = await _started(transaction.id);
      // The list again, after the load: whichever arrives first, the filing must hold.
      await _category(CategoryType.expense, 'Cà phê');
      await pumpEventQueue();

      expect(form.state.categoryId, food.id);
      expect(form.state.selectedCategory, isNull, reason: 'not on offer: the page shows it as uncategorised');

      await _send([const TransactionFormNoteChangeEvent('Bún chả'), const TransactionFormSubmitEvent()], form);

      expect(form.state.isSaved, isTrue);
      expect((await _stored()).single.categoryId, food.id);
    });

    test('an account archived since stays the account, rather than the transaction moving to the oldest', () async {
      await _account('Tiền mặt');
      final bank = await _account('Ngân hàng');
      final transaction = await _expense(bank);
      await _repositories.accounts.archiveAccount(bank.id);
      final form = await _started(transaction.id);
      await _account('Ví mới');
      await pumpEventQueue();

      expect(form.state.accountId, bank.id);
      expect(form.state.selectedAccount, isNull);
      expect(form.state.currencyCode, 'VND', reason: "the transaction's own, while its account is not on offer");

      await _send([const TransactionFormNoteChangeEvent('Bún chả'), const TransactionFormSubmitEvent()], form);

      expect((await _stored()).single.accountId, bank.id);
    });

    test('a transaction that is gone loads as not found, and a submit then writes nothing', () async {
      await _account('Tiền mặt');
      final form = await _started('tx-missing');

      expect(form.state.isLoading, isFalse);
      expect(form.state.original, isNull);
      expect(form.state.failure, const GPNotFoundFailure());

      await _send([const TransactionFormAmountChangeEvent(45000), const TransactionFormSubmitEvent()], form);

      expect(form.state.isSaved, isFalse);
      expect(await _stored(), isEmpty, reason: 'an edit with nothing loaded must not become a create');
    });

    test('a change made elsewhere after loading is a conflict, not an overwrite', () async {
      final transaction = await _expense(await _account('Tiền mặt'));
      final form = await _started(transaction.id);
      await _repositories.db.customStatement('UPDATE transactions SET version = version + 1');

      await _send([const TransactionFormNoteChangeEvent('Bún chả'), const TransactionFormSubmitEvent()], form);

      expect(form.state.failure, isA<GPConflictFailure>());
      expect((await _stored()).single.note, 'Phở');
    });
  });

  group('delete', () {
    test('writes at once and ends deleted', () async {
      final form = await _started((await _expense(await _account('Tiền mặt'))).id);

      await _send([const TransactionFormDeleteEvent()], form);

      expect(form.state.isDeleted, isTrue);
      expect(await _stored(), isEmpty);
    });

    test('a transaction deleted elsewhere meanwhile is not found, and the form stays', () async {
      final transaction = await _expense(await _account('Tiền mặt'));
      final form = await _started(transaction.id);
      await _repositories.transactions.deleteTransaction(transaction.id);

      await _send([const TransactionFormDeleteEvent()], form);

      expect(form.state.isDeleted, isFalse);
      expect(form.state.failure, const GPNotFoundFailure());
    });

    test('does nothing on a new transaction', () async {
      await _account('Tiền mặt');
      final form = await _started();
      final before = form.state;

      await _send([const TransactionFormDeleteEvent()], form);

      expect(form.state, before);
    });

    test('a save and a delete sent together do one thing: the delete meets a saved form', () async {
      final transaction = await _expense(await _account('Tiền mặt'));
      final form = await _started(transaction.id);

      await _send([const TransactionFormNoteChangeEvent('Bún chả'), const TransactionFormSubmitEvent(), const TransactionFormDeleteEvent()], form);

      expect(form.state.isSaved, isTrue);
      expect(form.state.isDeleted, isFalse);
      expect((await _stored()).single.note, 'Bún chả');
    });
  });

  group('transfer', () {
    test('offers as destinations only the other accounts in the same currency', () async {
      final cash = await _account('Tiền mặt');
      final bank = await _account('Ngân hàng');
      await _account('Ví đô', currency: 'USD');
      final form = await _started();

      await _send([const TransactionFormTypeChangeEvent(TransactionType.transfer)], form);

      expect(form.state.accountId, cash.id);
      expect(form.state.destinationsForSource, [bank]);
      expect(form.state.destinationAccountId, isNull, reason: 'none is picked for the user');
    });

    test('saves one row with its destination and no category', () async {
      final cash = await _account('Tiền mặt');
      final bank = await _account('Ngân hàng');
      final food = await _category(CategoryType.expense, 'Ăn uống');
      final form = await _started();

      await _send([
        TransactionFormCategoryChangeEvent(food.id),
        const TransactionFormTypeChangeEvent(TransactionType.transfer),
        TransactionFormDestinationChangeEvent(bank.id),
        const TransactionFormAmountChangeEvent(100000),
        const TransactionFormSubmitEvent(),
      ], form);

      expect(form.state.isSaved, isTrue);
      final saved = (await _stored()).single;
      expect(saved.type, TransactionType.transfer);
      expect(saved.accountId, cash.id);
      expect(saved.destinationAccountId, bank.id);
      expect(saved.categoryId, isNull);
    });

    test("no destination picked is the entity's refusal, which the form puts on the destination", () async {
      await _account('Tiền mặt');
      await _account('Ngân hàng');
      final form = await _started();

      await _send([const TransactionFormTypeChangeEvent(TransactionType.transfer), const TransactionFormAmountChangeEvent(100000), const TransactionFormSubmitEvent()], form);

      expect(form.state.failure, const GPValidationFailure(GPValidationCode.transactionDestinationMissing));
      expect(form.state.failedField, TransactionFormField.destination);
      expect(await _stored(), isEmpty);

      await _send([const TransactionFormNoteChangeEvent('Tiền nhà')], form);

      expect(form.state.failure, isNotNull, reason: 'the note cannot fix the destination');
    });

    test('switching to a transfer drops the category, and switching away drops the destination', () async {
      await _account('Tiền mặt');
      final bank = await _account('Ngân hàng');
      final food = await _category(CategoryType.expense, 'Ăn uống');
      final form = await _started();

      await _send([TransactionFormCategoryChangeEvent(food.id), const TransactionFormTypeChangeEvent(TransactionType.transfer)], form);
      expect(form.state.categoryId, isNull);

      await _send([TransactionFormDestinationChangeEvent(bank.id), const TransactionFormTypeChangeEvent(TransactionType.expense)], form);
      expect(form.state.destinationAccountId, isNull);
    });

    test('a source the destination cannot pair with drops it: the destination itself, or another currency', () async {
      final cash = await _account('Tiền mặt');
      final bank = await _account('Ngân hàng');
      final dollars = await _account('Ví đô', currency: 'USD');
      final form = await _started();

      await _send([
        const TransactionFormTypeChangeEvent(TransactionType.transfer),
        TransactionFormDestinationChangeEvent(bank.id),
        TransactionFormAccountChangeEvent(bank.id),
      ], form);
      expect(form.state.destinationAccountId, isNull);

      await _send([TransactionFormAccountChangeEvent(cash.id), TransactionFormDestinationChangeEvent(bank.id), TransactionFormAccountChangeEvent(dollars.id)], form);
      expect(form.state.destinationAccountId, isNull);
    });

    test('a destination not on offer is ignored: the source itself, or another currency', () async {
      final cash = await _account('Tiền mặt');
      final dollars = await _account('Ví đô', currency: 'USD');
      final form = await _started();

      await _send([
        const TransactionFormTypeChangeEvent(TransactionType.transfer),
        TransactionFormDestinationChangeEvent(cash.id),
        TransactionFormDestinationChangeEvent(dollars.id),
      ], form);

      expect(form.state.destinationAccountId, isNull);
    });

    test('a destination archived elsewhere is dropped, not replaced', () async {
      await _account('Tiền mặt');
      final bank = await _account('Ngân hàng');
      await _account('Thẻ');
      final form = await _started();
      await _send([const TransactionFormTypeChangeEvent(TransactionType.transfer), TransactionFormDestinationChangeEvent(bank.id)], form);

      await _repositories.accounts.archiveAccount(bank.id);
      await pumpEventQueue();

      expect(form.state.destinationAccountId, isNull);
    });

    test('an edit loads the destination and keeps it, archived or not, when the note changes', () async {
      final cash = await _account('Tiền mặt');
      final bank = await _account('Ngân hàng');
      final moved = await _transfer(cash, bank);
      await _repositories.accounts.archiveAccount(bank.id);
      final form = await _started(moved.id);
      await _account('Ví mới');
      await pumpEventQueue();

      expect(form.state.type, TransactionType.transfer);
      expect(form.state.destinationAccountId, bank.id);

      await _send([const TransactionFormNoteChangeEvent('Tiền nhà'), const TransactionFormSubmitEvent()], form);

      expect((await _stored()).single.destinationAccountId, bank.id);
    });

    test('an edited transfer switched to an expense is saved with no destination', () async {
      final cash = await _account('Tiền mặt');
      final moved = await _transfer(cash, await _account('Ngân hàng'));
      final form = await _started(moved.id);

      await _send([const TransactionFormTypeChangeEvent(TransactionType.expense), const TransactionFormSubmitEvent()], form);

      final saved = (await _stored()).single;
      expect(saved.type, TransactionType.expense);
      expect(saved.destinationAccountId, isNull);
    });
  });

  group('state', () {
    test('an edit that changes nothing emits nothing', () async {
      await _account('Tiền mặt');
      final form = await _started();
      await _send([const TransactionFormNoteChangeEvent('Phở')], form);
      final emitted = <TransactionFormState>[];
      final subscription = form.stream.listen(emitted.add);
      addTearDown(subscription.cancel);

      await _send([const TransactionFormNoteChangeEvent('Phở')], form);

      expect(emitted, isEmpty);
    });

    test('prints neither the amount nor the note (golden rule 9)', () async {
      await _account('Tiền mặt');
      final form = await _started();

      await _send([const TransactionFormAmountChangeEvent(45000), const TransactionFormNoteChangeEvent('Phở bò')], form);

      expect(form.state.toString(), isNot(contains('45000')));
      expect(form.state.toString(), isNot(contains('Phở')));
    });
  });

  group('a refused save', () {
    test('an amount refusal survives edits elsewhere and clears once the amount changes', () async {
      await _account('Tiền mặt');
      final food = await _category(CategoryType.expense, 'Ăn uống');
      final form = await _started();
      await _send([const TransactionFormSubmitEvent()], form);
      const refused = GPValidationFailure(GPValidationCode.transactionAmountNotPositive);
      expect(form.state.failure, refused);

      await _send([const TransactionFormNoteChangeEvent('Phở'), TransactionFormCategoryChangeEvent(food.id), TransactionFormDateChangeEvent(DateTime(2026, 10, 11))], form);
      expect(form.state.failure, refused, reason: 'none of those edits can fix the amount');

      await _send([const TransactionFormAmountChangeEvent(45000)], form);
      expect(form.state.failure, isNull);
    });

    test('a failure no field owns clears on any edit', () async {
      final accounts = StreamController<List<AccountEntity>>();
      addTearDown(accounts.close);
      getIt
        ..unregister<AccountRepository>()
        ..registerSingleton<AccountRepository>(FakeAccountRepository(accounts.stream));
      final cash = okValue(AccountEntity.create(initialBalance: Money(0, 'VND'), type: AccountType.cash, createdAt: _now, updatedAt: _now, id: 'acc-cash', name: 'Tiền mặt'));
      final form = await _started();
      accounts.add([cash]);
      await pumpEventQueue();

      accounts.addError(const GPDatabaseFailure());
      await pumpEventQueue();
      expect(form.state.failure, const GPDatabaseFailure());

      await _send([const TransactionFormNoteChangeEvent('Phở')], form);
      expect(form.state.failure, isNull);
    });
  });
}

TransactionFormBloc _form([String? transactionId]) {
  final form = TransactionFormBloc(transactionId: transactionId);
  addTearDown(form.close);
  return form;
}

/// The lists are in, and an edit's transaction is read.
Future<TransactionFormBloc> _started([String? transactionId]) async {
  final form = _form(transactionId);
  await pumpEventQueue();
  return form;
}

Future<void> _send(List<TransactionFormEvent> events, TransactionFormBloc form) async {
  events.forEach(form.add);
  await pumpEventQueue();
}

Future<AccountEntity> _account(String name, {String currency = 'VND'}) async =>
    okValue(await _repositories.accounts.createAccount(initialBalance: Money(0, currency), type: AccountType.cash, name: name));

Future<CategoryEntity> _category(CategoryType type, String name) async => okValue(await _repositories.categories.createCategory(type: type, name: name));

Future<TransactionEntity> _expense(AccountEntity on, {CategoryEntity? filedUnder, String? note = 'Phở'}) async => okValue(
  await _repositories.transactions.createTransaction(
    amount: Money(45000, on.initialBalance.currencyCode),
    type: TransactionType.expense,
    occurredAt: _eatenAt.toUtc(),
    accountId: on.id,
    categoryId: filedUnder?.id,
    note: note,
  ),
);

Future<TransactionEntity> _transfer(AccountEntity from, AccountEntity to) async => okValue(
  await _repositories.transactions.createTransaction(
    amount: Money(100000, from.initialBalance.currencyCode),
    type: TransactionType.transfer,
    occurredAt: _eatenAt.toUtc(),
    accountId: from.id,
    destinationAccountId: to.id,
    note: 'Chuyển',
  ),
);

Future<List<TransactionEntity>> _stored() async => (await _repositories.transactions.watchTransactions(TransactionQuery(limit: 10)).first).transactions;
