import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_balance.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/presentation/bloc/accounts_bloc.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

import '../../../../helpers/fake_transaction_repository.dart';
import '../../../../helpers/in_memory_repositories.dart';

void main() {
  tearDown(getIt.reset);

  test('starts loading, then holds every account with its balance', () async {
    final repositories = InMemoryRepositories();
    addTearDown(repositories.close);
    getIt.registerSingleton<TransactionRepository>(repositories.transactions);
    await repositories.accounts.createAccount(initialBalance: Money(150000, 'VND'), type: AccountType.cash, name: 'Ví');

    final bloc = AccountsBloc();
    addTearDown(bloc.close);

    expect(bloc.state, const AccountsInitState());
    await expectLater(
      bloc.stream,
      emitsInOrder([const AccountsLoadingState(null), isA<AccountsLoadedState>().having((state) => state.balances.single.balance, 'balance', Money(150000, 'VND'))]),
    );
  });

  test('a failure keeps the last list under it, and the next list clears it', () async {
    final balances = StreamController<List<AccountBalance>>();
    addTearDown(balances.close);
    getIt.registerSingleton<TransactionRepository>(FakeTransactionRepository(balances.stream));
    final bloc = AccountsBloc();
    addTearDown(bloc.close);

    balances
      ..add(const [])
      ..addError(const GPDatabaseFailure())
      ..add(const []);

    await expectLater(
      bloc.stream,
      emitsInOrder(const [
        AccountsLoadingState(null),
        AccountsLoadedState(<AccountBalance>[]),
        AccountsLoadErrorState(<AccountBalance>[], GPDatabaseFailure()),
        AccountsLoadedState(<AccountBalance>[]),
      ]),
    );
  });

  test('anything but a GPFailure is a bug: rethrown, never shown as a sentence', () async {
    final balances = StreamController<List<AccountBalance>>();
    addTearDown(balances.close);
    getIt.registerSingleton<TransactionRepository>(FakeTransactionRepository(balances.stream));
    final uncaught = <Object>[];
    late AccountsBloc bloc;

    runZonedGuarded(() => bloc = AccountsBloc(), (error, _) => uncaught.add(error));
    addTearDown(() => bloc.close());
    balances.addError(StateError('broken invariant'));
    await pumpEventQueue();

    expect(uncaught.single, isA<StateError>());
    expect(bloc.state, isNot(isA<AccountsLoadErrorState>()));
  });
}
