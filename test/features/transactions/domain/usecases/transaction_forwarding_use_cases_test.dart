import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/usecases/delete_transaction_use_case.dart';
import 'package:ghpockit/features/transactions/domain/usecases/restore_transaction_use_case.dart';
import 'package:ghpockit/features/transactions/domain/usecases/watch_transaction_use_case.dart';

import '../../../../helpers/in_memory_repositories.dart';

/// The three forward one call each (ADR-0013); these pin that they reach the repository with the id intact.
void main() {
  late InMemoryRepositories repositories;

  setUp(() => repositories = InMemoryRepositories());
  tearDown(() => repositories.close());

  T ok<T>(GPResult<T> result) => (result as GPOk<T>).value;

  Future<TransactionEntity> seed() async {
    final account = ok<AccountEntity>(await repositories.accounts.createAccount(name: 'Ví', type: AccountType.cash, initialBalance: Money(0, 'VND')));
    return ok(
      await repositories.transactions.createTransaction(type: TransactionType.expense, accountId: account.id, amount: Money(45000, 'VND'), occurredAt: DateTime.utc(2026, 10, 13)),
    );
  }

  test('watch one sees the transaction; delete takes it away and restore brings it back', () async {
    final created = await seed();
    final watch = WatchTransactionUseCase(transactionRepository: repositories.transactions);

    expect(await watch(created.id).first, created);

    expect(await DeleteTransactionUseCase(transactionRepository: repositories.transactions)(created.id), const GPOk<void>(null));
    expect(await watch(created.id).first, isNull);

    expect(await RestoreTransactionUseCase(transactionRepository: repositories.transactions)(created.id), const GPOk<void>(null));
    expect((await watch(created.id).first)?.id, created.id);
  });

  test("the repository's refusals come back unchanged", () async {
    final created = await seed();

    expect(await RestoreTransactionUseCase(transactionRepository: repositories.transactions)(created.id), const GPErr<void>(GPNotFoundFailure()));
    expect(await DeleteTransactionUseCase(transactionRepository: repositories.transactions)('tx-missing'), const GPErr<void>(GPNotFoundFailure()));
  });
}
