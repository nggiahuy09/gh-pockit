import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/currency_code.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/accounts/presentation/bloc/account_form_cubit.dart';

import '../../../../helpers/in_memory_repositories.dart';

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

  AccountFormCubit cubit({String? accountId}) {
    final created = AccountFormCubit(accountId: accountId);
    addTearDown(created.close);
    return created;
  }

  Future<List<AccountEntity>> stored() => repositories.accounts.watchAccounts().first;

  Future<AccountEntity> seed({String name = 'Ví', AccountType type = AccountType.cash, Money? balance}) async {
    final result = await repositories.accounts.createAccount(name: name, type: type, initialBalance: balance ?? Money(150000, 'VND'));
    return (result as GPOk<AccountEntity>).value;
  }

  group('create', () {
    test('starts blank, in the home currency, and not loading', () {
      final form = cubit();

      expect(form.isEditing, isFalse);
      expect(form.state, const AccountFormState());
    });

    test('saves what was typed and ends saved', () async {
      final form = cubit()
        ..nameChanged('Vietcombank')
        ..typeChanged(AccountType.bank)
        ..currencyChanged(CurrencyCode.usd)
        ..initialBalanceChanged(1250);

      await form.submit();

      expect(form.state.isSaved, isTrue);
      final account = (await stored()).single;
      expect(account.name, 'Vietcombank');
      expect(account.type, AccountType.bank);
      expect(account.initialBalance, Money(1250, 'USD'));
    });

    test('an owed balance is saved below zero', () async {
      final form = cubit()
        ..nameChanged('Thẻ')
        ..initialBalanceChanged(500000)
        ..owedChanged(isOwed: true);

      await form.submit();

      expect((await stored()).single.initialBalance, Money(-500000, 'VND'));
    });

    test('an empty balance is saved as zero', () async {
      final form = cubit()..nameChanged('Ví');

      await form.submit();

      expect((await stored()).single.initialBalance, Money(0, 'VND'));
    });

    test("a refused name is the entity's failure, and nothing is written", () async {
      final form = cubit()..nameChanged('   ');

      await form.submit();

      expect(form.state.failure, const GPValidationFailure(GPValidationCode.accountNameEmpty));
      expect(form.state.isSaving, isFalse);
      expect(form.state.isSaved, isFalse);
      expect(await stored(), isEmpty);
    });

    test('the next edit clears the failure', () async {
      final form = cubit()..nameChanged('');
      await form.submit();

      form.nameChanged('V');

      expect(form.state.failure, isNull);
    });

    test('a second submit after saving writes nothing more', () async {
      final form = cubit()..nameChanged('Ví');

      await form.submit();
      await form.submit();

      expect(await stored(), hasLength(1));
    });
  });

  group('edit', () {
    test('loads the account, splitting the balance into magnitude and sign', () async {
      final card = await seed(name: 'Thẻ', type: AccountType.creditCard, balance: Money(-300000, 'VND'));
      final form = cubit(accountId: card.id);
      expect(form.state.isLoading, isTrue);

      await form.load();

      expect(form.state.isLoading, isFalse);
      expect(form.state.original, card);
      expect(form.state.name, 'Thẻ');
      expect(form.state.type, AccountType.creditCard);
      expect(form.state.initialMinorUnits, 300000);
      expect(form.state.isOwed, isTrue);
    });

    test('saves the edit in place, keeping the id and the currency', () async {
      final wallet = await seed(balance: Money(1000, 'USD'));
      final form = cubit(accountId: wallet.id);
      await form.load();

      form
        ..nameChanged('Ví đô')
        ..currencyChanged(CurrencyCode.vnd)
        ..initialBalanceChanged(2500);
      await form.submit();

      expect(form.state.isSaved, isTrue);
      final account = (await stored()).single;
      expect(account.id, wallet.id);
      expect(account.name, 'Ví đô');
      expect(account.initialBalance, Money(2500, 'USD'));
    });

    test('an account that is gone loads as not found', () async {
      final form = cubit(accountId: 'acc-missing');

      await form.load();

      expect(form.state.isLoading, isFalse);
      expect(form.state.original, isNull);
      expect(form.state.failure, const GPNotFoundFailure());
    });

    test('an edit whose account failed to load never creates one in its place', () async {
      final form = cubit(accountId: 'acc-missing');
      await form.load();

      form.nameChanged('Ví mới');
      await form.submit();

      expect(form.state.isSaved, isFalse);
      expect(await stored(), isEmpty);
    });

    test('an account changed elsewhere after loading is a conflict, not an overwrite', () async {
      final wallet = await seed();
      final form = cubit(accountId: wallet.id);
      await form.load();
      await repositories.db.customStatement('UPDATE accounts SET version = version + 1');

      form.nameChanged('Ví mới');
      await form.submit();

      expect(form.state.failure, isA<GPConflictFailure>());
      expect((await stored()).single.name, 'Ví');
    });
  });

  group('a refused save', () {
    test('a name refusal survives edits elsewhere and clears once the name changes', () async {
      final form = cubit()..nameChanged('  ');
      await form.submit();
      const refused = GPValidationFailure(GPValidationCode.accountNameEmpty);

      form
        ..typeChanged(AccountType.bank)
        ..initialBalanceChanged(1000)
        ..owedChanged(isOwed: true);
      expect(form.state.failure, refused, reason: 'none of those edits can fix the name');

      form.nameChanged('Ví');
      expect(form.state.failure, isNull);
    });

    test('a conflict, which no field owns, clears on any edit', () async {
      final wallet = await seed();
      final form = cubit(accountId: wallet.id);
      await form.load();
      await repositories.db.customStatement('UPDATE accounts SET version = version + 1');
      await form.submit();
      expect(form.state.failure, isA<GPConflictFailure>());

      form.typeChanged(AccountType.bank);

      expect(form.state.failure, isNull);
    });
  });
}
