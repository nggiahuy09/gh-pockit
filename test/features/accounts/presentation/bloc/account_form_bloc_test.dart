import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/money/currency_code.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/accounts/presentation/bloc/account_form_bloc.dart';

import '../../../../helpers/in_memory_repositories.dart';
import '../../../../helpers/results.dart';

late InMemoryRepositories _repositories;

Future<List<AccountEntity>> _stored() => _repositories.accounts.watchAccounts().first;

Future<AccountEntity> _seed({Money? balance, AccountType type = AccountType.cash, String name = 'Ví'}) async =>
    okValue(await _repositories.accounts.createAccount(initialBalance: balance ?? Money(150000, 'VND'), type: type, name: name));

AccountFormBloc _bloc([String? accountId]) {
  final bloc = AccountFormBloc(accountId: accountId);
  addTearDown(bloc.close);
  return bloc;
}

Future<AccountFormState> _loaded(AccountFormBloc bloc) async => bloc.state.isLoading ? bloc.stream.firstWhere((state) => !state.isLoading) : bloc.state;

/// Waits for the save to land or be refused.
Future<AccountFormState> _submitted(AccountFormBloc bloc) {
  bloc.add(const AccountFormSubmitEvent());
  return bloc.stream.firstWhere((state) => state.isSaved || (!state.isSaving && state.failure != null));
}

Future<AccountFormState> _settled(AccountFormBloc bloc) async {
  await pumpEventQueue();
  return bloc.state;
}

void main() {
  setUp(() {
    _repositories = InMemoryRepositories();
    getIt.registerSingleton<AccountRepository>(_repositories.accounts);
  });

  tearDown(() async {
    await getIt.reset();
    await _repositories.close();
  });

  group('create', () {
    test('starts blank, in the home currency, and not loading', () {
      final bloc = _bloc();

      expect(bloc.state, const AccountFormState.initial(false));
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.currencyCode, 'VND');
    });

    test('saves what was typed and ends saved', () async {
      final bloc = _bloc()
        ..add(const AccountFormNameChangeEvent('Vietcombank'))
        ..add(const AccountFormTypeChangeEvent(AccountType.bank))
        ..add(const AccountFormCurrencyChangeEvent(CurrencyCode.usd))
        ..add(const AccountFormInitialBalanceChangeEvent(1250));

      expect((await _submitted(bloc)).isSaved, isTrue);
      final account = (await _stored()).single;
      expect(account.name, 'Vietcombank');
      expect(account.type, AccountType.bank);
      expect(account.initialBalance, Money(1250, 'USD'));
    });

    test('an owed balance is saved below zero', () async {
      final bloc = _bloc()
        ..add(const AccountFormNameChangeEvent('Thẻ'))
        ..add(const AccountFormInitialBalanceChangeEvent(500000))
        ..add(const AccountFormOwedChangeEvent(true));

      await _submitted(bloc);

      expect((await _stored()).single.initialBalance, Money(-500000, 'VND'));
    });

    test('an empty balance is saved as zero', () async {
      final bloc = _bloc()..add(const AccountFormNameChangeEvent('Ví'));

      await _submitted(bloc);

      expect((await _stored()).single.initialBalance, Money(0, 'VND'));
    });

    test("a refused name is the entity's failure, and nothing is written", () async {
      final bloc = _bloc()..add(const AccountFormNameChangeEvent('   '));

      final state = await _submitted(bloc);

      expect(state.failure, const GPValidationFailure(GPValidationCode.accountNameEmpty));
      expect(state.isSaving, isFalse);
      expect(state.isSaved, isFalse);
      expect(await _stored(), isEmpty);
    });

    test('the next edit clears the failure', () async {
      final bloc = _bloc()..add(const AccountFormNameChangeEvent(''));
      await _submitted(bloc);

      bloc.add(const AccountFormNameChangeEvent('V'));

      expect((await _settled(bloc)).failure, isNull);
    });

    test('a second submit after saving writes nothing more', () async {
      final bloc = _bloc()..add(const AccountFormNameChangeEvent('Ví'));
      await _submitted(bloc);

      bloc.add(const AccountFormSubmitEvent());
      await _settled(bloc);

      expect(await _stored(), hasLength(1));
    });
  });

  group('edit', () {
    test('loads the account, splitting the balance into magnitude and sign', () async {
      final card = await _seed(balance: Money(-300000, 'VND'), type: AccountType.creditCard, name: 'Thẻ');
      final bloc = _bloc(card.id);
      expect(bloc.state.isLoading, isTrue);

      final state = await _loaded(bloc);

      expect(state.isLoading, isFalse);
      expect(state.original, card);
      expect(state.name, 'Thẻ');
      expect(state.type, AccountType.creditCard);
      expect(state.initialMinorUnits, 300000);
      expect(state.isOwed, isTrue);
    });

    test('saves the edit in place, keeping the id and the currency', () async {
      final wallet = await _seed(balance: Money(1000, 'USD'));
      final bloc = _bloc(wallet.id);
      await _loaded(bloc);

      bloc
        ..add(const AccountFormNameChangeEvent('Ví đô'))
        ..add(const AccountFormCurrencyChangeEvent(CurrencyCode.vnd))
        ..add(const AccountFormInitialBalanceChangeEvent(2500));

      expect((await _submitted(bloc)).isSaved, isTrue);
      final account = (await _stored()).single;
      expect(account.id, wallet.id);
      expect(account.name, 'Ví đô');
      expect(account.initialBalance, Money(2500, 'USD'));
    });

    test('an account that is gone loads as not found', () async {
      final state = await _loaded(_bloc('acc-missing'));

      expect(state.isLoading, isFalse);
      expect(state.original, isNull);
      expect(state.failure, const GPNotFoundFailure());
    });

    test('an edit whose account failed to load never creates one in its place', () async {
      final bloc = _bloc('acc-missing');
      await _loaded(bloc);

      bloc
        ..add(const AccountFormNameChangeEvent('Ví mới'))
        ..add(const AccountFormSubmitEvent());

      expect((await _settled(bloc)).isSaved, isFalse);
      expect(await _stored(), isEmpty);
    });

    test('an account changed elsewhere after loading is a conflict, not an overwrite', () async {
      final wallet = await _seed();
      final bloc = _bloc(wallet.id);
      await _loaded(bloc);
      await _repositories.db.customStatement('UPDATE accounts SET version = version + 1');

      bloc.add(const AccountFormNameChangeEvent('Ví mới'));

      expect((await _submitted(bloc)).failure, isA<GPConflictFailure>());
      expect((await _stored()).single.name, 'Ví');
    });
  });

  group('a refused save', () {
    test('a name refusal survives edits elsewhere and clears once the name changes', () async {
      final bloc = _bloc()..add(const AccountFormNameChangeEvent('  '));
      await _submitted(bloc);

      bloc
        ..add(const AccountFormTypeChangeEvent(AccountType.bank))
        ..add(const AccountFormInitialBalanceChangeEvent(1000))
        ..add(const AccountFormOwedChangeEvent(true));
      expect((await _settled(bloc)).failure, const GPValidationFailure(GPValidationCode.accountNameEmpty), reason: 'none of those edits can fix the name');

      bloc.add(const AccountFormNameChangeEvent('Ví'));
      expect((await _settled(bloc)).failure, isNull);
    });

    test('a conflict, which no field owns, clears on any edit', () async {
      final wallet = await _seed();
      final bloc = _bloc(wallet.id);
      await _loaded(bloc);
      await _repositories.db.customStatement('UPDATE accounts SET version = version + 1');
      expect((await _submitted(bloc)).failure, isA<GPConflictFailure>());

      bloc.add(const AccountFormTypeChangeEvent(AccountType.bank));

      expect((await _settled(bloc)).failure, isNull);
    });
  });

  test('toString carries no name and no balance', () async {
    final bloc = _bloc()..add(const AccountFormNameChangeEvent('Lương tháng 9'));

    expect((await _settled(bloc)).toString(), isNot(contains('Lương')));
  });
}
