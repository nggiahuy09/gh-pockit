import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/features/accounts/data/daos/account_dao.dart';
import 'package:ghpockit/features/categories/data/daos/category_dao.dart';
import 'package:ghpockit/features/categories/data/seed/category_seeder.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/data/seed/benchmark_dataset_generator.dart';
import 'package:ghpockit/features/transactions/data/seed/benchmark_dataset_seeder.dart';
import 'package:ghpockit/features/transactions/data/seed/benchmark_dataset_size_enum.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/fake_uuid_generator.dart';

late GPAppDatabase _db;
late FakeClock _clock;
late BenchmarkDatasetSeeder _seeder;
late TransactionDao _transactionDao;

void main() {
  setUp(() async {
    _db = GPAppDatabase.forTesting(NativeDatabase.memory());
    _clock = FakeClock(DateTime.utc(2026, 11, 2, 2));
    _transactionDao = TransactionDao(_db);
    final categoryDao = CategoryDao(_db);
    await CategorySeeder(clock: _clock, dao: categoryDao, uuidGenerator: FakeUuidGenerator('cat'), ownerId: localOwnerId).seedDefaults();
    _seeder = BenchmarkDatasetSeeder(
      accountDao: AccountDao(_db),
      categoryDao: categoryDao,
      clock: _clock,
      generator: BenchmarkDatasetGenerator(uuidGenerator: FakeUuidGenerator('bench')),
      transactionDao: _transactionDao,
      ownerId: localOwnerId,
    );
  });

  tearDown(() => _db.close());

  test("writes the five accounts and every transaction, tombstones included, each one the owner's and 'pending'", () async {
    expect(await _seeder.seed(BenchmarkDatasetSize.k1), BenchmarkDatasetSize.k1.count);

    final rows = await _db.select(_db.transactionsTable).get();
    final tombstones = rows.where((row) => row.deletedAt != null).toList();
    expect(rows, hasLength(BenchmarkDatasetSize.k1.count));
    expect(await _db.select(_db.accountsTable).get(), hasLength(5));
    expect(tombstones, isNotEmpty);
    expect(tombstones.where((row) => row.deletedAt != _clock.nowEpochMillis()), isEmpty);
    expect(rows.where((row) => row.ownerId != localOwnerId || row.syncStatus != TransactionDao.pendingSyncStatus), isEmpty);
  });

  test('files rows under every category the seed wrote, and under no other', () async {
    await _seeder.seed(BenchmarkDatasetSize.k1);

    final seededIds = {for (final row in await _db.select(_db.categoriesTable).get()) row.id};
    final usedIds = {for (final row in await _db.select(_db.transactionsTable).get()) ?row.categoryId};
    expect(usedIds, seededIds);
  });

  test('writes nothing once the owner has a transaction, so a restart does not double the dataset', () async {
    await _seeder.seed(BenchmarkDatasetSize.k1);

    expect(await _seeder.seed(BenchmarkDatasetSize.k1), 0);
    expect(await _db.select(_db.transactionsTable).get(), hasLength(BenchmarkDatasetSize.k1.count));
    expect(await _db.select(_db.accountsTable).get(), hasLength(5));
  });

  test('wakes an open watch once for the whole dataset, not once per row', () async {
    var emissions = 0;
    final subscription = _transactionDao.watchAccountBalances(localOwnerId).listen((_) => emissions++);

    await pumpEventQueue();
    await _seeder.seed(BenchmarkDatasetSize.k1);
    await pumpEventQueue();
    await subscription.cancel();

    expect(emissions, 2, reason: 'the empty read, then one read after the commit');
  });
}
