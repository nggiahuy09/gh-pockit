import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';

import 'generated/schema.dart';

late SchemaVerifier _verifier;

void main() {
  // The fixtures are the committed `drift_schemas/` dumps, regenerated on every bump by the `drift_dev schema` commands in CLAUDE.md §9.

  setUpAll(() {
    _verifier = SchemaVerifier(GeneratedHelper());
  });

  test('migrates v1 → v2 into the schema a fresh v2 install has', () async {
    final connection = await _verifier.startAt(1);
    final db = GPAppDatabase.forTesting(connection);

    // Throws `SchemaMismatch` on any difference from the fixture, indexes included.
    await _verifier.migrateAndValidate(db, 2);

    await db.close();
  });

  test('carries v1 settings rows across the upgrade untouched', () async {
    final schema = await _verifier.schemaAt(1);

    // Raw SQL on the raw handle: the database is still v1, and `GPAppDatabase` describes the current schema.
    schema.rawDatabase.execute("INSERT INTO settings (key, value, updated_at) VALUES ('locale.selected', 'vi', 1757800000000)");

    final db = GPAppDatabase.forTesting(schema.newConnection());
    await _verifier.migrateAndValidate(db, 2);

    final row = await (db.select(db.settingsTable)..where((t) => t.key.equals('locale.selected'))).getSingle();
    expect(row.value, 'vi');
    expect(row.updatedAt, 1757800000000);

    await db.close();
  });

  test('leaves the new accounts table present and empty after the upgrade', () async {
    final connection = await _verifier.startAt(1);
    final db = GPAppDatabase.forTesting(connection);

    await _verifier.migrateAndValidate(db, 2);

    // `migrateAndValidate` checks shape only: a migration that also seeded a row would pass it.
    expect(await db.select(db.accountsTable).get(), isEmpty);

    await db.close();
  });

  test('creates the accounts index on the upgrade path, not just on a fresh install', () async {
    final connection = await _verifier.startAt(1);
    final db = GPAppDatabase.forTesting(connection);

    await _verifier.migrateAndValidate(db, 2);

    // Also covered by `migrateAndValidate`; stated on its own because a missing index changes no query result, only its cost.
    final indexes = await db.customSelect("SELECT name FROM sqlite_schema WHERE type = 'index' AND tbl_name = 'accounts'").get();

    expect(indexes.map((row) => row.read<String>('name')), contains('accounts_owner_id_is_archived'));

    await db.close();
  });

  test('migrates v2 → v3 into the schema a fresh v3 install has', () async {
    final connection = await _verifier.startAt(2);
    final db = GPAppDatabase.forTesting(connection);

    await _verifier.migrateAndValidate(db, 3);

    await db.close();
  });

  test('carries v2 accounts rows across the v3 upgrade untouched', () async {
    final schema = await _verifier.schemaAt(2);

    // Raw SQL: the database is still v2.
    schema.rawDatabase.execute(
      'INSERT INTO accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version) '
      "VALUES ('a1', 'local', 'Ví tiền mặt', 'cash', 'VND', 1500000, 0, 1757800000000, 1757800000000, 1)",
    );

    final db = GPAppDatabase.forTesting(schema.newConnection());
    await _verifier.migrateAndValidate(db, 3);

    final row = await (db.select(db.accountsTable)..where((t) => t.id.equals('a1'))).getSingle();
    expect(row.name, 'Ví tiền mặt');
    expect(row.initialBalance, 1500000);

    await db.close();
  });

  test('leaves the new categories table present and empty after the upgrade', () async {
    final connection = await _verifier.startAt(2);
    final db = GPAppDatabase.forTesting(connection);

    await _verifier.migrateAndValidate(db, 3);

    // Empty on purpose: `CategorySeeder` seeds at launch, never in a migration.
    expect(await db.select(db.categoriesTable).get(), isEmpty);

    await db.close();
  });

  test('creates both categories indexes on the upgrade path', () async {
    final connection = await _verifier.startAt(2);
    final db = GPAppDatabase.forTesting(connection);

    await _verifier.migrateAndValidate(db, 3);

    final indexes = await db.customSelect("SELECT name FROM sqlite_schema WHERE type = 'index' AND tbl_name = 'categories'").get();
    final names = indexes.map((row) => row.read<String>('name'));

    expect(names, contains('categories_owner_id_type'));
    expect(names, contains('categories_owner_id_name_key'));

    await db.close();
  });

  test('walks every step for a device that skipped a release', () async {
    final connection = await _verifier.startAt(1);
    final db = GPAppDatabase.forTesting(connection);

    await _verifier.migrateAndValidate(db, 3);

    expect(await db.select(db.accountsTable).get(), isEmpty);
    expect(await db.select(db.categoriesTable).get(), isEmpty);

    await db.close();
  });

  group('v3 → v4 (transactions)', () {
    // Raw SQL: the database is still v3.

    test('migrates into the schema a fresh v4 install has', () async {
      final connection = await _verifier.startAt(3);
      final db = GPAppDatabase.forTesting(connection);

      // Covers the foreign keys and the CHECKs too: they are part of the `CREATE TABLE`.
      await _verifier.migrateAndValidate(db, 4);

      await db.close();
    });

    test('carries v3 accounts and categories across untouched, and adds an empty transactions table', () async {
      final db = await _upgradedFromV3WithParents();

      expect((await db.select(db.accountsTable).getSingle()).initialBalance, 1500000);
      expect((await db.select(db.categoriesTable).getSingle()).nameKey, 'category.food');
      expect(await db.select(db.transactionsTable).get(), isEmpty);

      await db.close();
    });

    test('creates all four transactions indexes on the upgrade path', () async {
      final connection = await _verifier.startAt(3);
      final db = GPAppDatabase.forTesting(connection);

      await _verifier.migrateAndValidate(db, 4);

      final indexes = await db.customSelect("SELECT name FROM sqlite_schema WHERE type = 'index' AND tbl_name = 'transactions'").get();

      expect(
        indexes.map((row) => row.read<String>('name')),
        containsAll(<String>[
          'transactions_owner_id_occurred_at_id',
          'transactions_account_id_occurred_at_id',
          'transactions_destination_account_id_occurred_at_id',
          'transactions_category_id_occurred_at_id',
        ]),
      );

      await db.close();
    });

    test('enforces the new foreign keys against rows that predate them', () async {
      final db = await _upgradedFromV3WithParents();

      await db.into(db.transactionsTable).insert(_expense(accountId: 'a1', id: 't1'));
      await expectLater(
        db.into(db.transactionsTable).insert(_expense(accountId: 'a-ghost', id: 't2')),
        throwsA(isA<SqliteException>().having((e) => e.message, 'message', contains('FOREIGN KEY constraint failed'))),
      );

      await db.close();
    });

    test('walks v2 → v4 and v1 → v4 for devices that skipped releases', () async {
      for (final from in [2, 1]) {
        final connection = await _verifier.startAt(from);
        final db = GPAppDatabase.forTesting(connection);

        await _verifier.migrateAndValidate(db, 4);

        expect(await db.select(db.transactionsTable).get(), isEmpty, reason: 'from v$from');

        await db.close();
      }
    });
  });

  group('v4 → v5 (the account indexes cover the balance, ADR-0027)', () {
    test('migrates into the schema a fresh v5 install has', () async {
      final connection = await _verifier.startAt(4);
      final db = GPAppDatabase.forTesting(connection);

      await _verifier.migrateAndValidate(db, 5);

      await db.close();
    });

    test('keeps every v4 transaction, and the balances read the same over the rebuilt indexes', () async {
      final db = await _upgradedFromV4WithTransactions();

      final balances = await db.customSelect(TransactionDao.accountBalancesSql, variables: [Variable.withString('local')]).get();

      expect(await db.select(db.transactionsTable).get(), hasLength(3));
      expect({for (final row in balances) row.read<String>('id'): row.read<int>('balance_minor')}, {'a1': 1500000 - 125000 - 300000, 'a2': 300000});

      await db.close();
    });

    test('rebuilds both account indexes wide enough that the balance never reads the table', () async {
      final db = await _upgradedFromV4WithTransactions();

      final plan = await db.customSelect('EXPLAIN QUERY PLAN ${TransactionDao.accountBalancesSql}', variables: [Variable.withString('local')]).get();

      expect(
        plan.map((row) => row.read<String>('detail')),
        containsAll(<String>[
          'SEARCH t USING COVERING INDEX transactions_account_id_occurred_at_id (account_id=?)',
          'SEARCH t USING COVERING INDEX transactions_destination_account_id_occurred_at_id (destination_account_id=?)',
        ]),
      );

      await db.close();
    });

    test('walks v3, v2 and v1 → v5 for devices that skipped releases', () async {
      for (final from in [3, 2, 1]) {
        final connection = await _verifier.startAt(from);
        final db = GPAppDatabase.forTesting(connection);

        await _verifier.migrateAndValidate(db, 5);

        await db.close();
      }
    });
  });

  group('a migration that dies part-way (ADR-0029)', () {
    // `_fault` takes the name of the last index the v4 step creates, so the step fails after everything before it ran — the state a kill
    // there leaves. Dropping it afterwards is the next launch, where whatever killed the app is gone.

    test('a failed step leaves the database at the version before it, with nothing of the step behind', () async {
      final schema = await _verifier.schemaAt(3);
      schema.rawDatabase
        ..execute(_fault)
        ..execute(_v3Account);

      await expectLater(_open(schema.newConnection()), throwsA(_faultHit));

      expect(schema.rawDatabase.userVersion, 3);
      expect(_objectsOutsideFault(schema.rawDatabase.select(_schemaObjects)), isNot(contains(startsWith('transactions'))));
      // Raw: opening `GPAppDatabase` again would migrate again.
      expect(schema.rawDatabase.select('SELECT name FROM accounts').single['name'], 'Ví tiền mặt');
    });

    test('the next launch runs the failed step again in full', () async {
      final schema = await _verifier.schemaAt(3);
      schema.rawDatabase
        ..execute(_fault)
        ..execute(_v3Account);
      await expectLater(_open(schema.newConnection()), throwsA(_faultHit));

      schema.rawDatabase.execute(_faultGone);
      final db = GPAppDatabase.forTesting(schema.newConnection());

      // Without the rollback this throws "index transactions_owner_id_occurred_at_id already exists" on every launch.
      await _verifier.migrateAndValidate(db, 5);
      expect((await db.select(db.accountsTable).getSingle()).initialBalance, 1500000);

      await db.close();
    });

    test('a device several releases behind keeps the steps that committed before the failure', () async {
      final schema = await _verifier.schemaAt(1);
      schema.rawDatabase
        ..execute(_fault)
        ..execute("INSERT INTO settings (key, value, updated_at) VALUES ('locale.selected', 'vi', 1757800000000)");

      await expectLater(_open(schema.newConnection()), throwsA(_faultHit));

      // v2 and v3 committed with their own version; drift wrote none, since the open failed.
      expect(schema.rawDatabase.userVersion, 3);
      expect(
        _objectsOutsideFault(schema.rawDatabase.select(_schemaObjects)),
        unorderedEquals(<String>['settings', 'accounts', 'accounts_owner_id_is_archived', 'categories', 'categories_owner_id_type', 'categories_owner_id_name_key']),
      );

      schema.rawDatabase.execute(_faultGone);
      final db = GPAppDatabase.forTesting(schema.newConnection());
      await _verifier.migrateAndValidate(db, 5);
      expect((await db.select(db.settingsTable).getSingle()).value, 'vi');

      await db.close();
    });

    test('a first launch that fails leaves an empty database, and the next one creates it all', () async {
      final schema = await _verifier.schemaAt(1);
      // A fresh file: the verifier's v1 minus its one table and its version.
      schema.rawDatabase
        ..execute('DROP TABLE settings')
        ..userVersion = 0
        ..execute(_fault);

      await expectLater(_open(schema.newConnection()), throwsA(_faultHit));

      expect(schema.rawDatabase.userVersion, 0);
      expect(_objectsOutsideFault(schema.rawDatabase.select(_schemaObjects)), isEmpty);

      schema.rawDatabase.execute(_faultGone);
      final db = GPAppDatabase.forTesting(schema.newConnection());
      await _verifier.migrateAndValidate(db, 5);

      await db.close();
    });
  });
}

const _fault = 'CREATE TABLE fault (x INTEGER); CREATE INDEX transactions_category_id_occurred_at_id ON fault (x)';
const _faultGone = 'DROP TABLE fault';
const _schemaObjects = "SELECT name FROM sqlite_schema WHERE name NOT LIKE 'sqlite_%'";
const _v3Account =
    'INSERT INTO accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version) '
    "VALUES ('a1', 'local', 'Ví tiền mặt', 'cash', 'VND', 1500000, 0, 1757800000000, 1757800000000, 1)";

final Matcher _faultHit = isA<SqliteException>().having((e) => e.message, 'message', contains('transactions_category_id_occurred_at_id already exists'));

/// The first query opens the database, which is where drift migrates.
Future<void> _open(QueryExecutor executor) async {
  final db = GPAppDatabase.forTesting(executor);
  try {
    await db.customSelect('SELECT 1').get();
  } finally {
    await db.close();
  }
}

List<String> _objectsOutsideFault(Iterable<Map<String, Object?>> rows) => [
  for (final row in rows)
    if (row['name'] case final String name when name != 'fault' && name != 'transactions_category_id_occurred_at_id') name,
];

/// Two accounts, an expense, a transfer between them and a tombstone, written as v4 SQL.
Future<GPAppDatabase> _upgradedFromV4WithTransactions() async {
  final schema = await _verifier.schemaAt(4);
  const columns = '(id, owner_id, type, account_id, destination_account_id, amount_minor, currency_code, occurred_at, created_at, updated_at, version, deleted_at, sync_status)';
  schema.rawDatabase
    ..execute(
      'INSERT INTO accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version) VALUES '
      "('a1', 'local', 'Ví tiền mặt', 'cash', 'VND', 1500000, 0, 1757800000000, 1757800000000, 1), "
      "('a2', 'local', 'Ví điện tử', 'e_wallet', 'VND', 0, 0, 1757800000000, 1757800000000, 1)",
    )
    ..execute(
      'INSERT INTO transactions $columns VALUES '
      "('t1', 'local', 'expense', 'a1', NULL, 125000, 'VND', 1790573400000, 1790573400000, 1790573400000, 1, NULL, 'pending'), "
      "('t2', 'local', 'transfer', 'a1', 'a2', 300000, 'VND', 1790573500000, 1790573500000, 1790573500000, 1, NULL, 'pending'), "
      "('t3', 'local', 'expense', 'a2', NULL, 99000, 'VND', 1790573600000, 1790573600000, 1790573700000, 1, 1790573700000, 'pending')",
    );

  final db = GPAppDatabase.forTesting(schema.newConnection());
  await _verifier.migrateAndValidate(db, 5);
  return db;
}

Future<GPAppDatabase> _upgradedFromV3WithParents() async {
  final schema = await _verifier.schemaAt(3);
  schema.rawDatabase
    ..execute(
      'INSERT INTO accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version) '
      "VALUES ('a1', 'local', 'Ví tiền mặt', 'cash', 'VND', 1500000, 0, 1757800000000, 1757800000000, 1)",
    )
    ..execute(
      'INSERT INTO categories (id, owner_id, name_key, type, is_system, created_at, updated_at, version) '
      "VALUES ('c1', 'local', 'category.food', 'expense', 1, 1757800000000, 1757800000000, 1)",
    );

  final db = GPAppDatabase.forTesting(schema.newConnection());
  await _verifier.migrateAndValidate(db, 4);
  return db;
}

TransactionsTableCompanion _expense({required String accountId, required String id}) => TransactionsTableCompanion.insert(
  id: id,
  ownerId: 'local',
  type: 'expense',
  accountId: accountId,
  categoryId: const Value('c1'),
  amountMinor: 125000,
  currencyCode: 'VND',
  occurredAt: 1790573400000,
  createdAt: 1790573400000,
  updatedAt: 1790573400000,
  version: 1,
  syncStatus: 'pending',
);
