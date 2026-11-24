import 'package:drift/drift.dart' show DatabaseConnection, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/database/settings_owner_context.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/data/daos/account_dao.dart';
import 'package:ghpockit/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/auth/data/daos/device_owner_dao.dart';
import 'package:ghpockit/features/auth/data/repositories/device_owner_repository_impl.dart';
import 'package:ghpockit/features/categories/data/daos/category_dao.dart';
import 'package:ghpockit/features/categories/data/repositories/category_repository_impl.dart';
import 'package:ghpockit/features/categories/data/seed/category_seeder.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/fake_uuid_generator.dart';
import '../../../../helpers/recording_logger.dart';
import '../../../../helpers/results.dart';

const _user = 'uid-1';

/// The whole data layer on one in-memory database and the real settings-backed owner, as the app wires it (ADR-0040).
void main() {
  late FakeClock clock;
  late RecordingLogger logger;
  late GPAppDatabase db;
  late FakeUuidGenerator uuid;
  late GPSettingsOwnerContext owner;
  late AccountRepositoryImpl accounts;
  late CategoryRepositoryImpl categories;
  late TransactionRepositoryImpl transactions;
  late CategorySeeder seeder;
  late DeviceOwnerRepositoryImpl deviceOwner;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 11, 10, 9));
    logger = RecordingLogger(clock);
    db = GPAppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    uuid = FakeUuidGenerator();
    owner = GPSettingsOwnerContext(database: db, logger: logger);
    await owner.load();
    accounts = AccountRepositoryImpl(clock: clock, dao: AccountDao(db), logger: logger, uuidGenerator: uuid, ownerContext: owner);
    categories = CategoryRepositoryImpl(clock: clock, dao: CategoryDao(db), logger: logger, uuidGenerator: uuid, ownerContext: owner);
    transactions = TransactionRepositoryImpl(clock: clock, dao: TransactionDao(db), logger: logger, uuidGenerator: uuid, ownerContext: owner);
    seeder = CategorySeeder(clock: clock, dao: CategoryDao(db), ownerContext: owner, uuidGenerator: uuid);
    deviceOwner = DeviceOwnerRepositoryImpl(clock: clock, dao: DeviceOwnerDao(db), logger: logger, ownerContext: owner, seeder: seeder, uuidGenerator: uuid);
  });

  tearDown(() async {
    await owner.dispose();
    await db.close();
  });

  Future<List<Map<String, Object?>>> rows(String table) async => (await db.customSelect('SELECT * FROM $table ORDER BY id').get()).map((row) => row.data).toList();

  Future<String> seededId(String ownerId, CategoryType type) async {
    final seeded =
        (await db
                .customSelect(
                  'SELECT name_key FROM categories WHERE owner_id = ? AND type = ? AND name_key IS NOT NULL ORDER BY name_key LIMIT 1',
                  variables: [Variable.withString(ownerId), Variable.withString(type.storageValue)],
                )
                .getSingle())
            .read<String>('name_key');
    return CategorySeeder.seededId(uuid, nameKey: seeded, ownerId: ownerId);
  }

  /// Days of offline use before signing up: seeds, two accounts, an own category, spending in both, a transfer, one deleted.
  Future<({AccountEntity cash, AccountEntity bank, String foodId, String ownCategoryId})> useOffline() async {
    await seeder.seedDefaults();
    final cash = okValue(await accounts.createAccount(initialBalance: Money(500000, 'VND'), type: AccountType.cash, name: 'Ví'));
    final bank = okValue(await accounts.createAccount(initialBalance: Money(0, 'VND'), type: AccountType.bank, name: 'VCB'));
    final ownCategory = okValue(await categories.createCategory(type: CategoryType.expense, name: 'Cà phê'));
    final foodId = await seededId(localOwnerId, CategoryType.expense);
    final day = DateTime.utc(2026, 11, 8, 10);

    okValue(
      await transactions.createTransaction(
        amount: Money(45000, 'VND'),
        type: TransactionType.expense,
        occurredAt: day,
        accountId: cash.id,
        categoryId: foodId,
      ),
    );
    okValue(
      await transactions.createTransaction(
        amount: Money(30000, 'VND'),
        type: TransactionType.expense,
        occurredAt: day,
        accountId: cash.id,
        categoryId: ownCategory.id,
      ),
    );
    okValue(
      await transactions.createTransaction(
        amount: Money(100000, 'VND'),
        type: TransactionType.transfer,
        occurredAt: day,
        accountId: cash.id,
        destinationAccountId: bank.id,
      ),
    );
    final deleted = okValue(
      await transactions.createTransaction(
        amount: Money(1000, 'VND'),
        type: TransactionType.expense,
        occurredAt: day,
        accountId: cash.id,
        categoryId: foodId,
      ),
    );
    okValue(await transactions.deleteTransaction(deleted.id));
    return (cash: cash, bank: bank, foodId: foodId, ownCategoryId: ownCategory.id);
  }

  test('days offline, then a sign-up: every row is still there, and every row is the user’s', () async {
    final before = await useOffline();
    final counts = {
      for (final table in ['accounts', 'categories', 'transactions']) table: (await rows(table)).length,
    };
    clock.advance(const Duration(days: 3));

    final moved = okValue(await deviceOwner.claimLocalData(_user));

    expect(moved, counts.values.reduce((a, b) => a + b));
    for (final table in counts.keys) {
      final after = await rows(table);
      expect(after, hasLength(counts[table]), reason: table);
      expect(after.map((row) => row['owner_id']).toSet(), {_user}, reason: table);
      expect(after.map((row) => row['version']).toSet(), isNot(contains(1)), reason: '$table: every moved row is a new version');
      expect(after.map((row) => row['updated_at']).toSet(), {clock.nowEpochMillis()}, reason: table);
    }
    expect(owner.current, _user);
    expect(deviceOwner.ownerId, _user);
    // Not synced yet, and still waiting: W13 backfills a mutation for every pending row.
    expect((await rows('transactions')).map((row) => row['sync_status']).toSet(), {'pending'});

    // The repositories now read the user's rows: nothing lost from the user's point of view.
    expect((await accounts.watchAccounts().first).map((account) => account.id), [before.cash.id, before.bank.id]);
    expect((await transactions.watchTransactions(TransactionQuery(limit: 50)).first).items, hasLength(3));
  });

  test('seeded categories take the user’s derived ids, and the transactions follow; an own category keeps its id', () async {
    final before = await useOffline();

    okValue(await deviceOwner.claimLocalData(_user));

    final userFoodId = CategorySeeder.seededId(uuid, nameKey: before.foodId.split('|').last, ownerId: _user);
    final categoryIds = (await rows('categories')).map((row) => row['id']).toSet();
    expect(categoryIds, contains(userFoodId));
    expect(categoryIds, isNot(contains(before.foodId)));
    expect(categoryIds, contains(before.ownCategoryId));
    final pointedAt = (await rows('transactions')).map((row) => row['category_id']).toSet();
    expect(pointedAt, containsAll([userFoodId, before.ownCategoryId]));
    expect(pointedAt, isNot(contains(before.foodId)));
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test('the seed after a claim adds nothing: no category twice', () async {
    await useOffline();
    final categoriesBefore = (await rows('categories')).length;

    okValue(await deviceOwner.claimLocalData(_user));

    expect(await seeder.seedDefaults(), 0);
    expect(await rows('categories'), hasLength(categoriesBefore));
  });

  test('a second claim changes nothing', () async {
    await useOffline();
    okValue(await deviceOwner.claimLocalData(_user));
    final snapshot = {
      for (final table in ['accounts', 'categories', 'transactions']) table: await rows(table),
    };
    clock.advance(const Duration(hours: 1));

    expect(okValue(await deviceOwner.claimLocalData(_user)), 0);

    for (final table in snapshot.keys) {
      expect(await rows(table), snapshot[table], reason: table);
    }
  });

  test('a list already open follows the claim instead of going empty', () async {
    final before = await useOffline();
    final seen = <List<String>>[];
    final subscription = accounts.watchAccounts().listen((list) => seen.add(list.map((account) => account.id).toList()));
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    okValue(await deviceOwner.claimLocalData(_user));
    await pumpEventQueue();

    expect(seen.last, [before.cash.id, before.bank.id]);
    expect(seen, everyElement(isNotEmpty));
  });

  test('the user’s own seed already here: the local copy goes, and its transactions move to the user’s', () async {
    final before = await useOffline();
    final userFoodId = CategorySeeder.seededId(uuid, nameKey: before.foodId.split('|').last, ownerId: _user);
    await db.customStatement(
      'INSERT INTO categories (id, owner_id, name_key, type, is_system, created_at, updated_at, version) '
      'SELECT ?, ?, name_key, type, is_system, created_at, updated_at, version FROM categories WHERE id = ?',
      [userFoodId, _user, before.foodId],
    );

    okValue(await deviceOwner.claimLocalData(_user));

    final ids = (await rows('categories')).map((row) => row['id']).toList();
    expect(ids.where((id) => id == userFoodId), hasLength(1));
    expect(ids, isNot(contains(before.foodId)));
    expect((await rows('transactions')).map((row) => row['category_id']), isNot(contains(before.foodId)));
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test('a claim that fails rolls back whole: still local, still the local owner, a database failure', () async {
    final before = await useOffline();
    // Refuses the last table's move, after the categories were re-ided and two tables moved: all of it must roll back.
    await db.customStatement("CREATE TRIGGER refuse_claim BEFORE UPDATE OF owner_id ON transactions BEGIN SELECT RAISE(ABORT, 'refused'); END");
    final snapshot = {
      for (final table in ['accounts', 'categories', 'transactions']) table: await rows(table),
    };

    final result = await deviceOwner.claimLocalData(_user);

    expect(result, const GPErr<int>(GPDatabaseFailure()));
    for (final table in snapshot.keys) {
      expect(await rows(table), snapshot[table], reason: table);
    }
    expect(owner.current, localOwnerId);
    expect(await db.customSelect("SELECT * FROM settings WHERE key = 'owner.id'").get(), isEmpty);
    expect(logger.last.message, 'local data claim failed');
    expect((await accounts.watchAccounts().first).map((account) => account.id), [before.cash.id, before.bank.id]);
  });

  test('the owner survives a relaunch: a new context reads it back', () async {
    await useOffline();
    okValue(await deviceOwner.claimLocalData(_user));

    final relaunched = GPSettingsOwnerContext(database: db, logger: logger);
    addTearDown(relaunched.dispose);
    await relaunched.load();

    expect(relaunched.current, _user);
  });

  group('unsynced changes (ADR-0042)', () {
    test('untouched seeded categories are not changes', () async {
      await seeder.seedDefaults();

      expect(okValue(await deviceOwner.countUnsyncedChanges()), 0);
    });

    test('every account, every own category and every pending transaction counts, deleted ones too', () async {
      await useOffline();

      // 2 accounts, 1 own category, 4 transactions (one deleted).
      expect(okValue(await deviceOwner.countUnsyncedChanges()), 7);
    });

    test('a renamed or deleted seed counts', () async {
      await seeder.seedDefaults();
      final foodId = await seededId(localOwnerId, CategoryType.expense);
      await db.customStatement("UPDATE categories SET name = 'Ăn uống' WHERE id = ?", [foodId]);

      expect(okValue(await deviceOwner.countUnsyncedChanges()), 1);
    });

    test('a seed with a new icon or colour counts', () async {
      await seeder.seedDefaults();
      final foodId = await seededId(localOwnerId, CategoryType.expense);
      final salaryId = await seededId(localOwnerId, CategoryType.income);
      await db.customStatement("UPDATE categories SET icon_key = 'coffee' WHERE id = ?", [foodId]);
      await db.customStatement("UPDATE categories SET color_key = 'teal' WHERE id = ?", [salaryId]);

      expect(okValue(await deviceOwner.countUnsyncedChanges()), 2);
    });

    test("only the device owner's rows count", () async {
      await useOffline();
      okValue(await deviceOwner.claimLocalData(_user));
      await db.customStatement("UPDATE transactions SET sync_status = 'synced'");

      expect(okValue(await deviceOwner.countUnsyncedChanges()), 3);
    });
  });

  group('release (ADR-0042)', () {
    test("deletes the owner's rows, keeps settings, gives the device back to 'local' and reseeds", () async {
      await useOffline();
      okValue(await deviceOwner.claimLocalData(_user));
      await db.into(db.settingsTable).insert(SettingsTableCompanion.insert(key: 'locale.selected', value: 'vi', updatedAt: 0));
      final seen = <List<String>>[];
      final subscription = accounts.watchAccounts().listen((list) => seen.add(list.map((account) => account.id).toList()));
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      okValue(await deviceOwner.releaseDevice());
      await pumpEventQueue();

      expect(await rows('accounts'), isEmpty);
      expect(await rows('transactions'), isEmpty);
      final categories = await rows('categories');
      expect(categories, isNotEmpty);
      expect(categories.map((row) => row['owner_id']).toSet(), {localOwnerId});
      expect(categories.every((row) => row['name_key'] != null), isTrue);
      expect(owner.current, localOwnerId);
      expect((await db.customSelect('SELECT key FROM settings').get()).map((row) => row.data['key']), isNot(contains('owner.id')));
      expect((await db.customSelect('SELECT key FROM settings').get()).map((row) => row.data['key']), contains('locale.selected'));
      expect(seen.last, isEmpty);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    });

    test("an unclaimed device keeps its 'local' rows: they belong to no account", () async {
      await useOffline();
      final before = (await rows('accounts')).length;

      okValue(await deviceOwner.releaseDevice());

      expect(await rows('accounts'), hasLength(before));
    });

    test('a wipe that fails rolls back and keeps the owner', () async {
      await useOffline();
      okValue(await deviceOwner.claimLocalData(_user));
      await db.customStatement("CREATE TRIGGER refuse_wipe BEFORE DELETE ON accounts BEGIN SELECT RAISE(ABORT, 'refused'); END");

      expect(await deviceOwner.releaseDevice(), const GPErr<void>(GPDatabaseFailure()));
      expect(await rows('transactions'), isNotEmpty);
      expect(owner.current, _user);
    });
  });
}
