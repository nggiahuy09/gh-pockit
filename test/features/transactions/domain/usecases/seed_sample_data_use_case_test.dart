import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/settings/presentation/debug/sample_data.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/usecases/seed_sample_data_use_case.dart';
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_list_bloc.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/in_memory_repositories.dart';

const _accounts = [SampleAccount(type: AccountType.cash, name: 'Cash'), SampleAccount(type: AccountType.bank, name: 'Bank')];
const _transactions = [
  SampleTransaction(type: TransactionType.expense, time: (9, 30), note: 'Coffee', account: 0, amount: 45000, daysAgo: 0),
  SampleTransaction(type: TransactionType.transfer, time: (23, 59), account: 1, amount: 100000, daysAgo: 1, destination: 0),
];
const _input = SeedSampleDataInput(accounts: _accounts, transactions: _transactions);

void main() {
  late InMemoryRepositories repositories;
  late SeedSampleDataUseCase seedSampleData;

  setUp(() {
    repositories = InMemoryRepositories(FakeClock(DateTime(2026, 10, 11, 12)));
    seedSampleData = SeedSampleDataUseCase(repositories.accounts, repositories.clock, repositories.transactions);
  });
  tearDown(() => repositories.close());

  test('writes every account and transaction, dated relative to today in local time', () async {
    expect(await seedSampleData.execute(_input), const GPOk(2));

    final written = (await repositories.transactions.watchTransactions(TransactionQuery(limit: 10)).first).transactions;
    expect(written.map((transaction) => transaction.occurredAt.toLocal()), [DateTime(2026, 10, 11, 9, 30), DateTime(2026, 10, 10, 23, 59)]);
    final names = {for (final account in await repositories.accounts.watchAccounts().first) account.id: account.name};
    expect(names[written.last.accountId], 'Bank');
    expect(names[written.last.destinationAccountId], 'Cash');
  });

  test('seeding twice adds the rows again but reuses the accounts by name', () async {
    await seedSampleData.execute(_input);
    await seedSampleData.execute(_input);

    expect(await repositories.accounts.watchAccounts().first, hasLength(2));
    expect(await _rowCount(repositories), 4);
  });

  test('onlyIfEmpty leaves a database that already has a transaction alone', () async {
    await seedSampleData.execute(_input);

    expect(await seedSampleData.execute(const SeedSampleDataInput(accounts: _accounts, transactions: _transactions, onlyIfEmpty: true)), const GPOk(0));
    expect(await _rowCount(repositories), 2);
  });

  test('a refused row stops the seed and comes back as the failure', () async {
    const input = SeedSampleDataInput(
      accounts: [
        SampleAccount(type: AccountType.cash, name: 'Cash'),
        SampleAccount(type: AccountType.bank, currencyCode: 'USD', name: 'Chase'),
      ],
      transactions: [SampleTransaction(type: TransactionType.transfer, time: (9, 0), account: 0, amount: 100, daysAgo: 0, destination: 1)],
    );

    expect(await seedSampleData.execute(input), isA<GPErr<int>>().having((result) => result.failure, 'failure', isA<GPValidationFailure>()));
  });

  test('the shipped dataset seeds cleanly and spans more than one page', () async {
    final result = await seedSampleData.execute(const SeedSampleDataInput(accounts: sampleAccounts, transactions: sampleTransactions));

    expect(result, GPOk(sampleTransactions.length));
    expect(sampleTransactions.length, greaterThan(TransactionListBloc.pageSize));
    expect(await _rowCount(repositories), sampleTransactions.length);
  });

  test('the input logs counts, never names or notes', () {
    expect(_input.toLog(), {'accounts': 2, 'transactions': 2, 'only_if_empty': false});
  });
}

Future<int> _rowCount(InMemoryRepositories repositories) async => (await repositories.transactions.watchTransactions(TransactionQuery(limit: 1000)).first).rowCount;
