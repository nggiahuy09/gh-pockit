import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/domain/use_case.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/usecases/create_account_use_case.dart';
import 'package:ghpockit/features/accounts/domain/usecases/update_account_use_case.dart';
import 'package:ghpockit/features/accounts/domain/usecases/watch_account_use_case.dart';
import 'package:ghpockit/features/accounts/domain/usecases/watch_accounts_use_case.dart';

import '../../../../helpers/in_memory_repositories.dart';
import '../../../../helpers/results.dart';

/// The four forward one call each (ADR-0013); these pin that they reach the repository with every argument intact.
void main() {
  late InMemoryRepositories repositories;

  setUp(() => repositories = InMemoryRepositories());
  tearDown(() => repositories.close());

  test('create writes the account it is given, currency included', () async {
    final created = okValue(await CreateAccountUseCase(repositories.accounts).execute(CreateAccountInput(Money(-500, 'USD'), AccountType.creditCard, 'Visa')));

    expect(created.name, 'Visa');
    expect(created.type, AccountType.creditCard);
    expect(created.initialBalance, Money(-500, 'USD'));
  });

  test('watch one and watch all see the same row, and update moves it', () async {
    final created = okValue(await repositories.accounts.createAccount(initialBalance: Money(0, 'VND'), type: AccountType.cash, name: 'Ví'));

    expect(await WatchAccountsUseCase(repositories.accounts).execute(const GPNoInput()).first, [created]);
    expect(await WatchAccountUseCase(repositories.accounts).execute(WatchAccountInput(created.id)).first, created);

    final renamed = okValue(await UpdateAccountUseCase(repositories.accounts).execute(UpdateAccountInput(okValue(created.update(name: 'Ví mới')))));

    expect(renamed.name, 'Ví mới');
    expect((await repositories.accounts.watchAccount(created.id).first)!.name, 'Ví mới');
  });

  test('watch all leaves archived accounts out', () async {
    final created = okValue(await repositories.accounts.createAccount(initialBalance: Money(0, 'VND'), type: AccountType.cash, name: 'Cũ'));
    await repositories.accounts.archiveAccount(created.id);

    expect(await WatchAccountsUseCase(repositories.accounts).execute(const GPNoInput()).first, isEmpty);
  });

  test('inputs log ids and codes, never a name or an amount', () {
    expect(CreateAccountInput(Money(-500, 'USD'), AccountType.creditCard, 'Visa').toLog(), {'type': 'credit_card', 'currency_code': 'USD'});
    expect(const WatchAccountInput('acc-1').toLog(), {'account_id': 'acc-1'});
  });
}
