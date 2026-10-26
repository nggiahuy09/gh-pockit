import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/usecases/delete_transaction_use_case.dart';
import 'package:ghpockit/features/transactions/domain/usecases/restore_transaction_use_case.dart';
import 'package:ghpockit/features/transactions/domain/usecases/watch_transaction_use_case.dart';

import '../../../../helpers/in_memory_repositories.dart';
import '../../../../helpers/results.dart';

void main() {
  late InMemoryRepositories repositories;

  setUp(() => repositories = InMemoryRepositories());
  tearDown(() => repositories.close());

  test('watch one sees the transaction; delete takes it away and restore brings it back', () async {
    final created = await _seed(repositories);
    final watch = WatchTransactionUseCase(repositories.transactions);
    final input = WatchTransactionInput(created.id);

    expect(await watch.execute(input).first, created);

    expect(await DeleteTransactionUseCase(repositories.transactions).execute(DeleteTransactionInput(created.id)), const GPOk<void>(null));
    expect(await watch.execute(input).first, isNull);

    expect(await RestoreTransactionUseCase(repositories.transactions).execute(RestoreTransactionInput(created.id)), const GPOk<void>(null));
    expect((await watch.execute(input).first)?.id, created.id);
  });

  test("the repository's refusals come back unchanged", () async {
    final created = await _seed(repositories);

    expect(await RestoreTransactionUseCase(repositories.transactions).execute(RestoreTransactionInput(created.id)), const GPErr<void>(GPNotFoundFailure()));
    expect(await DeleteTransactionUseCase(repositories.transactions).execute(const DeleteTransactionInput('tx-missing')), const GPErr<void>(GPNotFoundFailure()));
  });

  test('each input logs the transaction id and nothing else', () {
    const id = 'tx-1';

    for (final input in const [DeleteTransactionInput(id), RestoreTransactionInput(id), WatchTransactionInput(id)]) {
      expect(input.toLog(), {'transaction_id': id}, reason: '${input.runtimeType}');
    }
  });
}

Future<TransactionEntity> _seed(InMemoryRepositories repositories) async {
  final account = okValue(await repositories.accounts.createAccount(initialBalance: Money(0, 'VND'), type: AccountType.cash, name: 'Ví'));
  return okValue(
    await repositories.transactions.createTransaction(amount: Money(45000, 'VND'), type: TransactionType.expense, occurredAt: DateTime.utc(2026, 10, 13), accountId: account.id),
  );
}
