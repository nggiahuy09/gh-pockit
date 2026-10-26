import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/usecases/create_sample_transaction_use_case.dart';

import '../../../../helpers/fake_account_repository.dart';
import '../../../../helpers/in_memory_repositories.dart';
import '../../../../helpers/results.dart';

const _input = CreateSampleTransactionInput(accountName: 'Ví mẫu', note: 'Giao dịch mẫu');

void main() {
  late InMemoryRepositories repositories;
  late CreateSampleTransactionUseCase createSampleTransaction;

  setUp(() {
    repositories = InMemoryRepositories();
    createSampleTransaction = CreateSampleTransactionUseCase(repositories.accounts, repositories.clock, repositories.transactions);
  });
  tearDown(() => repositories.close());

  test('with no account, creates a cash account first and writes the expense into it', () async {
    final sample = okValue(await createSampleTransaction.execute(_input));

    final accounts = await repositories.accounts.watchAccounts().first;
    expect(accounts.map((account) => (account.name, account.type)), [('Ví mẫu', AccountType.cash)]);
    expect(sample.accountId, accounts.single.id);
    expect(sample.type, TransactionType.expense);
    expect(sample.note, 'Giao dịch mẫu');
    expect(sample.occurredAt, repositories.clock.nowUtc());
  });

  test('reuses the oldest account, in its own currency', () async {
    final oldest = okValue(await repositories.accounts.createAccount(initialBalance: Money.zero('USD'), type: AccountType.bank, name: 'Chase'));
    await repositories.accounts.createAccount(initialBalance: Money.zero('VND'), type: AccountType.cash, name: 'Cash');

    final sample = okValue(await createSampleTransaction.execute(_input));

    expect(sample.accountId, oldest.id);
    expect(sample.amount.currencyCode, 'USD');
    expect(await repositories.accounts.watchAccounts().first, hasLength(2), reason: 'no extra account when one exists');
  });

  test('a failure reading the accounts comes back as the result, not a throw', () async {
    final failing = CreateSampleTransactionUseCase(FakeAccountRepository(Stream.error(const GPDatabaseFailure())), repositories.clock, repositories.transactions);

    expect(await failing.execute(_input), const GPErr<TransactionEntity>(GPDatabaseFailure()));
  });

  test('the input logs nothing: the name and the note are text', () {
    expect(_input.toLog(), isEmpty);
  });
}
