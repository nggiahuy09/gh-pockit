import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/usecases/create_account_use_case.dart';
import 'package:ghpockit/features/accounts/domain/usecases/update_account_use_case.dart';
import 'package:ghpockit/features/accounts/domain/usecases/watch_account_use_case.dart';
import 'package:ghpockit/features/accounts/domain/usecases/watch_accounts_use_case.dart';

import '../../../../helpers/in_memory_repositories.dart';

/// The four forward one call each (ADR-0013); these pin that they reach the repository with every argument intact.
void main() {
  late InMemoryRepositories repositories;

  setUp(() => repositories = InMemoryRepositories());
  tearDown(() => repositories.close());

  T ok<T>(GPResult<T> result) => (result as GPOk<T>).value;

  test('create writes the account it is given, currency included', () async {
    final created = ok(await CreateAccountUseCase(accountRepository: repositories.accounts)(name: 'Visa', type: AccountType.creditCard, initialBalance: Money(-500, 'USD')));

    expect(created.name, 'Visa');
    expect(created.type, AccountType.creditCard);
    expect(created.initialBalance, Money(-500, 'USD'));
  });

  test('watch one and watch all see the same row, and update moves it', () async {
    final created = ok(await repositories.accounts.createAccount(name: 'Ví', type: AccountType.cash, initialBalance: Money(0, 'VND')));

    expect(await WatchAccountsUseCase(accountRepository: repositories.accounts)().first, <AccountEntity>[created]);
    expect(await WatchAccountUseCase(accountRepository: repositories.accounts)(created.id).first, created);

    final renamed = ok(await UpdateAccountUseCase(accountRepository: repositories.accounts)(ok(created.update(name: 'Ví mới'))));

    expect(renamed.name, 'Ví mới');
    expect((await repositories.accounts.watchAccount(created.id).first)!.name, 'Ví mới');
  });

  test('watch all passes includeArchived through', () async {
    final created = ok(await repositories.accounts.createAccount(name: 'Cũ', type: AccountType.cash, initialBalance: Money(0, 'VND')));
    await repositories.accounts.archiveAccount(created.id);
    final watch = WatchAccountsUseCase(accountRepository: repositories.accounts);

    expect(await watch().first, isEmpty);
    expect(await watch(includeArchived: true).first, hasLength(1));
  });
}
