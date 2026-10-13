import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_deletion_cubit.dart';

import '../../../../helpers/in_memory_repositories.dart';

void main() {
  late InMemoryRepositories repositories;

  setUp(() {
    repositories = InMemoryRepositories();
    getIt.registerSingleton<TransactionRepository>(repositories.transactions);
  });

  tearDown(() async {
    await getIt.reset();
    await repositories.close();
  });

  T ok<T>(GPResult<T> result) => (result as GPOk<T>).value;

  TransactionDeletionCubit cubit() {
    final created = TransactionDeletionCubit();
    addTearDown(created.close);
    return created;
  }

  Future<(AccountEntity, TransactionEntity)> seed() async {
    final account = ok<AccountEntity>(await repositories.accounts.createAccount(name: 'Ví', type: AccountType.cash, initialBalance: Money(0, 'VND')));
    final transaction = ok(
      await repositories.transactions.createTransaction(type: TransactionType.expense, accountId: account.id, amount: Money(45000, 'VND'), occurredAt: DateTime.utc(2026, 10, 13)),
    );
    return (account, transaction);
  }

  Future<List<TransactionEntity>> listed() async => (await repositories.transactions.watchTransactions(TransactionQuery(limit: 10)).first).transactions;

  test('delete writes at once, and restore brings the same transaction back', () async {
    final (_, transaction) = await seed();
    final deletion = cubit();

    expect(await deletion.delete(transaction.id), const GPOk<void>(null));
    expect(await listed(), isEmpty);

    expect(await deletion.restore(transaction.id), const GPOk<void>(null));
    expect((await listed()).single.id, transaction.id);
  });

  test('is busy while a write is in flight, and idle after', () async {
    final (_, transaction) = await seed();
    final deletion = cubit();
    final states = <bool>[];
    final subscription = deletion.stream.listen(states.add);
    addTearDown(subscription.cancel);

    await deletion.delete(transaction.id);
    await pumpEventQueue();

    expect(states, <bool>[true, false]);
  });

  test('a restore refused because the account went meanwhile is returned, and the transaction stays deleted', () async {
    final (account, transaction) = await seed();
    final deletion = cubit();
    await deletion.delete(transaction.id);
    await repositories.accounts.deleteAccount(account.id);

    expect(await deletion.restore(transaction.id), const GPErr<void>(GPNotFoundFailure()));
    expect(await listed(), isEmpty);
  });

  test('a delete of a transaction already gone is returned as not found', () async {
    expect(await cubit().delete('tx-missing'), const GPErr<void>(GPNotFoundFailure()));
  });
}
