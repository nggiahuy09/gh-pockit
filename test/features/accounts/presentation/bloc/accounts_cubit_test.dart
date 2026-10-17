import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_balance.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/presentation/bloc/accounts_cubit.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

import '../../../../helpers/fake_transaction_repository.dart';
import '../../../../helpers/in_memory_repositories.dart';

void main() {
  tearDown(getIt.reset);

  test('starts loading, then holds every account with its balance', () async {
    final repositories = InMemoryRepositories();
    addTearDown(repositories.close);
    getIt.registerSingleton<TransactionRepository>(repositories.transactions);
    await repositories.accounts.createAccount(name: 'Ví', type: AccountType.cash, initialBalance: Money(150000, 'VND'));

    final cubit = AccountsCubit();
    addTearDown(cubit.close);
    expect(cubit.state.balances, isNull);

    cubit.start();
    await pumpEventQueue();

    expect(cubit.state.balances!.single.balance, Money(150000, 'VND'));
    expect(cubit.state.failure, isNull);
  });

  test('a failure keeps the last list under it, and the next list clears it', () async {
    final balances = StreamController<List<AccountBalance>>();
    addTearDown(balances.close);
    getIt.registerSingleton<TransactionRepository>(FakeTransactionRepository(balances: balances.stream));
    final cubit = AccountsCubit()..start();
    addTearDown(cubit.close);

    balances.add(const <AccountBalance>[]);
    await pumpEventQueue();
    balances.addError(const GPDatabaseFailure());
    await pumpEventQueue();

    expect(cubit.state.failure, const GPDatabaseFailure());
    expect(cubit.state.balances, isEmpty);

    balances.add(const <AccountBalance>[]);
    await pumpEventQueue();
    expect(cubit.state.failure, isNull);
  });

  test('anything but a GPFailure is a bug: rethrown, never shown as a sentence', () async {
    final balances = StreamController<List<AccountBalance>>();
    addTearDown(balances.close);
    getIt.registerSingleton<TransactionRepository>(FakeTransactionRepository(balances: balances.stream));
    final uncaught = <Object>[];
    late AccountsCubit cubit;

    runZonedGuarded(() => cubit = AccountsCubit()..start(), (Object error, StackTrace stackTrace) => uncaught.add(error));
    addTearDown(() => cubit.close());
    balances.addError(StateError('broken invariant'));
    await pumpEventQueue();

    expect(uncaught.single, isA<StateError>());
    expect(cubit.state.failure, isNull);
  });
}
