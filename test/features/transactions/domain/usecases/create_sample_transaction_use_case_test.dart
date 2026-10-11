import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/usecases/create_sample_transaction_use_case.dart';

import '../../../../helpers/fake_account_repository.dart';
import '../../../../helpers/in_memory_repositories.dart';

void main() {
  late InMemoryRepositories repos;
  late CreateSampleTransactionUseCase createSample;

  setUp(() {
    repos = InMemoryRepositories();
    createSample = CreateSampleTransactionUseCase(accountRepository: repos.accounts, transactionRepository: repos.transactions, clock: repos.clock);
  });
  tearDown(() => repos.close());

  TransactionEntity valueOf(GPResult<TransactionEntity> result) => (result as GPOk<TransactionEntity>).value;

  test('with no account, creates a cash account first and writes the expense into it', () async {
    final sample = valueOf(await createSample(accountName: 'Ví mẫu', note: 'Giao dịch mẫu'));

    final accounts = await repos.accounts.watchAccounts().first;
    expect(accounts.map((AccountEntity a) => (a.name, a.type)), [('Ví mẫu', AccountType.cash)]);
    expect(sample.accountId, accounts.single.id);
    expect(sample.type, TransactionType.expense);
    expect(sample.note, 'Giao dịch mẫu');
    expect(sample.occurredAt, repos.clock.nowUtc());
  });

  test('reuses the oldest account, in its own currency', () async {
    final oldest = await repos.accounts.createAccount(name: 'Chase', type: AccountType.bank, initialBalance: Money.zero('USD'));
    await repos.accounts.createAccount(name: 'Cash', type: AccountType.cash, initialBalance: Money.zero('VND'));

    final sample = valueOf(await createSample(accountName: 'Ví mẫu', note: 'Giao dịch mẫu'));

    expect(sample.accountId, (oldest as GPOk<AccountEntity>).value.id);
    expect(sample.amount.currencyCode, 'USD');
    expect(await repos.accounts.watchAccounts().first, hasLength(2), reason: 'no extra account when one exists');
  });

  test('a failure reading the accounts comes back as the result, not a throw', () async {
    final failing = CreateSampleTransactionUseCase(
      accountRepository: FakeAccountRepository(accounts: Stream<List<AccountEntity>>.error(const GPDatabaseFailure())),
      transactionRepository: repos.transactions,
      clock: repos.clock,
    );

    expect(await failing(accountName: 'Ví mẫu', note: 'Giao dịch mẫu'), const GPErr<TransactionEntity>(GPDatabaseFailure()));
  });
}
