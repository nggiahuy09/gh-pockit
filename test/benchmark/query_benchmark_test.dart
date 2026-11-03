import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/utils/calendar_month.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/core/utils/uuid_generator.dart';
import 'package:ghpockit/features/accounts/data/daos/account_dao.dart';
import 'package:ghpockit/features/categories/data/daos/category_dao.dart';
import 'package:ghpockit/features/categories/data/seed/category_seeder.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:ghpockit/features/transactions/data/seed/benchmark_dataset_generator.dart';
import 'package:ghpockit/features/transactions/data/seed/benchmark_dataset_seeder.dart';
import 'package:ghpockit/features/transactions/data/seed/benchmark_dataset_size_enum.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';

import '../helpers/recording_logger.dart';
import 'benchmark_timing.dart';

/// `sql` is the statement the DAO watches, read once with `get()`; `repository` is the first emission of the watch the bloc subscribes to.
typedef _Case = ({String name, Future<List<Object?>> Function() sql, Future<Object?> Function() repository, Future<String> Function() plan});

/// The query tier of the harness (ADR-0026): `fvm flutter test test/benchmark --dart-define=DATASET=10k`. A plain `flutter test` skips it.
void main() {
  final size = BenchmarkDatasetSize.fromKey(const String.fromEnvironment('DATASET'));
  if (size == null) {
    test('query benchmark', () {}, skip: 'measures only with --dart-define=DATASET=1k|10k|50k');
    return;
  }

  const clock = GPSystemClock();
  final report = <String>[];
  final plans = <String>[];
  late Directory directory;
  late GPAppDatabase db;
  late TransactionDao dao;
  late TransactionRepositoryImpl repository;
  late String busiestAccountId;
  late String quietestAccountId;
  late String categoryId;
  late GPCalendarMonth month;
  late List<Variable<Object>> monthVariables;
  final ownerVariables = [Variable.withString(localOwnerId)];

  final cases = <_Case>[
    for (final limit in const [50, 500, 2000])
      (
        name: 'list, newest $limit',
        sql: () => dao.selectTransactions(localOwnerId, limit: limit).get(),
        repository: () => repository.watchTransactions(TransactionQuery(limit: limit)).first,
        plan: () => _planOf(db, dao.selectTransactions(localOwnerId, limit: limit)),
      ),
    for (final (label, accountId) in [('busiest account', () => busiestAccountId), ('quietest account', () => quietestAccountId), (_newAccountLabel, () => _newAccountId)])
      (
        name: 'list, $label, newest 50',
        sql: () => dao.selectTransactions(localOwnerId, accountIds: {accountId.call()}, limit: 50).get(),
        repository: () => repository.watchTransactions(TransactionQuery(accountIds: {accountId.call()}, limit: 50)).first,
        plan: () => _planOf(db, dao.selectTransactions(localOwnerId, accountIds: {accountId.call()}, limit: 50)),
      ),
    (
      name: 'list, busiest category, newest 50',
      sql: () => dao.selectTransactions(localOwnerId, categoryIds: {categoryId}, limit: 50).get(),
      repository: () => repository.watchTransactions(TransactionQuery(categoryIds: {categoryId}, limit: 50)).first,
      plan: () => _planOf(db, dao.selectTransactions(localOwnerId, categoryIds: {categoryId}, limit: 50)),
    ),
    (
      name: 'month totals (Home)',
      sql: () => db.customSelect(TransactionDao.incomeExpenseTotalsSql, variables: monthVariables).get(),
      repository: () => repository.watchIncomeExpenseTotals(currencyCode: 'VND', from: month.start, to: month.end).first,
      plan: () => _rawPlanOf(db, TransactionDao.incomeExpenseTotalsSql, monthVariables),
    ),
    (
      name: 'month spending by category (Home)',
      sql: () => db.customSelect(TransactionDao.spendingByCategorySql, variables: monthVariables).get(),
      repository: () => repository.watchSpendingByCategory(currencyCode: 'VND', from: month.start, to: month.end).first,
      plan: () => _rawPlanOf(db, TransactionDao.spendingByCategorySql, monthVariables),
    ),
    (
      name: 'account balances (Home, Accounts)',
      sql: () => db.customSelect(TransactionDao.accountBalancesSql, variables: ownerVariables).get(),
      repository: () => repository.watchAccountBalances().first,
      plan: () => _rawPlanOf(db, TransactionDao.accountBalancesSql, ownerVariables),
    ),
  ];

  setUpAll(() async {
    directory = Directory.systemTemp.createTempSync('pockit-benchmark');
    db = GPAppDatabase.forTesting(_openConnection(directory.path));
    dao = TransactionDao(db);
    final categoryDao = CategoryDao(db);
    await CategorySeeder(
      clock: clock,
      dao: categoryDao,
      uuidGenerator: GPUuidGeneratorImpl(clock: clock),
      ownerId: localOwnerId,
    ).seedDefaults();

    final stopwatch = Stopwatch()..start();
    await BenchmarkDatasetSeeder(
      accountDao: AccountDao(db),
      categoryDao: categoryDao,
      clock: clock,
      generator: BenchmarkDatasetGenerator(
        uuidGenerator: GPUuidGeneratorImpl(clock: clock, random: Random(BenchmarkDatasetGenerator.defaultSeed)),
      ),
      transactionDao: dao,
      ownerId: localOwnerId,
    ).seed(size);
    final seedMillis = stopwatch.elapsedMilliseconds;

    repository = TransactionRepositoryImpl(
      clock: clock,
      dao: dao,
      logger: RecordingLogger(clock),
      uuidGenerator: GPUuidGeneratorImpl(clock: clock),
      ownerId: localOwnerId,
    );
    busiestAccountId = await _accountByTraffic(db, busiest: true);
    quietestAccountId = await _accountByTraffic(db, busiest: false);
    categoryId = await _busiest(db, 'category_id');
    await _addNewAccount(AccountDao(db), dao, clock.nowEpochMillis());
    final today = clock.nowUtc().toLocal();
    // The last whole month: the current one holds only as many days as today's date.
    month = GPCalendarMonth.of(DateTime(today.year, today.month - 1));
    monthVariables = [
      Variable.withString(localOwnerId),
      Variable.withString('VND'),
      Variable.withInt(month.start.millisecondsSinceEpoch),
      Variable.withInt(month.end.millisecondsSinceEpoch),
    ];

    final tombstones = await db.customSelect('SELECT COUNT(*) AS n FROM transactions WHERE deleted_at IS NOT NULL').getSingle();
    final sqliteVersion = await db.customSelect('SELECT sqlite_version() AS v').getSingle();
    // One pass over every case first: otherwise the first one also pays for compiling the paths the others share.
    for (final benchmarkCase in cases) {
      await benchmarkCase.sql.call();
      await benchmarkCase.repository.call();
    }

    report.addAll([
      '# Query benchmark — ${size.key}, host',
      '',
      '- Run ${today.toIso8601String()} on ${Platform.operatingSystem} ${Platform.operatingSystemVersion}; SQLite ${sqliteVersion.read<String>('v')}.',
      '- Dart ${Platform.version.split(' ').first} in JIT (`flutter test`): the Dart side runs slower here than in a profile build.',
      '- ${size.count} transactions, ${tombstones.read<int>('n')} of them tombstones, over 24 months (ADR-0025); seeded in $seedMillis ms.',
      '- Plus an account opened this week with $_newAccountRows transactions: too few to fill a page, so its list walks the whole owner index.',
      '- The month cases read ${month.year}-${month.month.toString().padLeft(2, '0')}, the last whole month.',
      '- Each case: 5 warm-up runs, then 30 measured. Milliseconds.',
      '',
      '| Case | Rows | SQL + copy, median | p90 | Repository, median | p90 | max |',
      '| ---- | ---: | -----------------: | --: | -----------------: | --: | --: |',
    ]);
  });

  tearDownAll(() async {
    await db.close();
    directory.deleteSync(recursive: true);

    final text = [...report, '', '## Plans', ...plans, ''].join('\n');
    File('build/benchmarks/queries-${size.key}.md')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
    stdout.writeln(text);
  });

  for (final benchmarkCase in cases) {
    test(benchmarkCase.name, () async {
      final rows = (await benchmarkCase.sql.call()).length;
      final sql = await measure(benchmarkCase.sql);
      final mapped = await measure(benchmarkCase.repository);

      report.add(
        '| ${benchmarkCase.name} | $rows | ${millis(sql.medianMicros)} | ${millis(sql.p90Micros)} | ${millis(mapped.medianMicros)} | '
        '${millis(mapped.p90Micros)} | ${millis(mapped.maxMicros)} |',
      );
      plans.addAll(['', '### ${benchmarkCase.name}', '', '```', await benchmarkCase.plan.call(), '```']);
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}

/// The connection the app opens: a file, on a background isolate, so every result pays the copy across isolates as it does on a phone. Top-level
/// because the path callbacks are sent to that isolate, and a closure inside `main` would drag the whole test state along.
QueryExecutor _openConnection(String path) => openAppConnection(name: 'bench', databaseDirectory: () async => Directory(path), tempDirectoryPath: () async => path);

const _newAccountId = 'benchmark-new-account';
const _newAccountLabel = 'account with 3 rows';
const _newAccountRows = 3;

/// Counts both sides of a transfer, as the account filter does.
Future<String> _accountByTraffic(GPAppDatabase db, {required bool busiest}) async {
  final row = await db
      .customSelect(
        'SELECT a.id FROM accounts a ORDER BY (SELECT COUNT(*) FROM transactions t WHERE t.account_id = a.id OR t.destination_account_id = a.id) '
        '${busiest ? 'DESC' : 'ASC'} LIMIT 1',
      )
      .getSingle();

  return row.read<String>('id');
}

Future<void> _addNewAccount(AccountDao accountDao, TransactionDao transactionDao, int now) async {
  await accountDao.insertAccount(
    AccountsTableCompanion.insert(
      id: _newAccountId,
      ownerId: localOwnerId,
      name: 'Tài khoản mới',
      type: 'bank',
      currencyCode: 'VND',
      initialBalance: 0,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
      version: 1,
    ),
  );
  await transactionDao.insertTransactions([
    for (var i = 0; i < _newAccountRows; i++)
      TransactionsTableCompanion.insert(
        id: '$_newAccountId-$i',
        ownerId: localOwnerId,
        type: 'expense',
        accountId: _newAccountId,
        amountMinor: 50000,
        currencyCode: 'VND',
        occurredAt: now - Duration(days: i).inMilliseconds,
        createdAt: now,
        updatedAt: now,
        version: 1,
        syncStatus: TransactionDao.pendingSyncStatus,
      ),
  ]);
}

Future<String> _busiest(GPAppDatabase db, String column) async {
  final row = await db.customSelect('SELECT $column AS id FROM transactions WHERE $column IS NOT NULL GROUP BY $column ORDER BY COUNT(*) DESC LIMIT 1').getSingle();

  return row.read<String>('id');
}

Future<String> _planOf(GPAppDatabase db, JoinedSelectStatement<HasResultSet, dynamic> statement) async {
  final query = statement.constructQuery();

  return _rawPlanOf(db, query.sql, query.introducedVariables);
}

Future<String> _rawPlanOf(GPAppDatabase db, String sql, List<Variable<Object>> variables) async {
  final rows = await db.customSelect('EXPLAIN QUERY PLAN $sql', variables: variables).get();

  return rows.map((row) => row.read<String>('detail')).join('\n');
}
