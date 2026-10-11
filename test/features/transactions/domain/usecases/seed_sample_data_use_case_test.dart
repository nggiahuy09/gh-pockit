import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/settings/presentation/debug/sample_data.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/usecases/seed_sample_data_use_case.dart';
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_list_bloc.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/in_memory_repositories.dart';

void main() {
  late InMemoryRepositories repos;
  late SeedSampleDataUseCase seed;

  const accounts = <SampleAccount>[SampleAccount('Cash', AccountType.cash), SampleAccount('Bank', AccountType.bank)];
  const transactions = <SampleTransaction>[
    SampleTransaction(daysAgo: 0, time: (9, 30), type: TransactionType.expense, amount: 45000, account: 0, note: 'Coffee'),
    SampleTransaction(daysAgo: 1, time: (23, 59), type: TransactionType.transfer, amount: 100000, account: 1, destination: 0),
  ];

  setUp(() {
    repos = InMemoryRepositories(clock: FakeClock(DateTime(2026, 10, 11, 12)));
    seed = SeedSampleDataUseCase(accountRepository: repos.accounts, transactionRepository: repos.transactions, clock: repos.clock);
  });
  tearDown(() => repos.close());

  Future<int> rowCount() async => (await repos.transactions.watchTransactions(TransactionQuery(limit: 1000)).first).rowCount;

  test('writes every account and transaction, dated relative to today in local time', () async {
    expect(await seed(accounts: accounts, transactions: transactions), const GPOk<int>(2));

    final written = (await repos.transactions.watchTransactions(TransactionQuery(limit: 10)).first).transactions;
    expect(written.map((t) => t.occurredAt.toLocal()), [DateTime(2026, 10, 11, 9, 30), DateTime(2026, 10, 10, 23, 59)]);
    final names = {for (final AccountEntity a in await repos.accounts.watchAccounts().first) a.id: a.name};
    expect(names[written.last.accountId], 'Bank');
    expect(names[written.last.destinationAccountId], 'Cash');
  });

  test('seeding twice adds the rows again but reuses the accounts by name', () async {
    await seed(accounts: accounts, transactions: transactions);
    await seed(accounts: accounts, transactions: transactions);

    expect(await repos.accounts.watchAccounts().first, hasLength(2));
    expect(await rowCount(), 4);
  });

  test('onlyIfEmpty leaves a database that already has a transaction alone', () async {
    await seed(accounts: accounts, transactions: transactions);

    expect(await seed(accounts: accounts, transactions: transactions, onlyIfEmpty: true), const GPOk<int>(0));
    expect(await rowCount(), 2);
  });

  test('a refused row stops the seed and comes back as the failure', () async {
    const mismatched = <SampleAccount>[SampleAccount('Cash', AccountType.cash), SampleAccount('Chase', AccountType.bank, currencyCode: 'USD')];
    const transfer = <SampleTransaction>[SampleTransaction(daysAgo: 0, time: (9, 0), type: TransactionType.transfer, amount: 100, account: 0, destination: 1)];

    expect(await seed(accounts: mismatched, transactions: transfer), isA<GPErr<int>>().having((e) => e.failure, 'failure', isA<GPValidationFailure>()));
  });

  test('the shipped dataset seeds cleanly and spans more than one page', () async {
    final result = await seed(accounts: sampleAccounts, transactions: sampleTransactions);

    expect(result, GPOk<int>(sampleTransactions.length));
    expect(sampleTransactions.length, greaterThan(TransactionListBloc.pageSize));
    expect(await rowCount(), sampleTransactions.length);
  });
}
