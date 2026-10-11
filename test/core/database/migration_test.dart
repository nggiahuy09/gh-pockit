import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';

import 'generated/schema.dart';

void main() {
  // The fixtures are the committed `drift_schemas/` dumps, regenerated on every bump by the `drift_dev schema` commands in CLAUDE.md §9.
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('migrates v1 → v2 into the schema a fresh v2 install has', () async {
    final connection = await verifier.startAt(1);
    final db = GPAppDatabase.forTesting(connection);

    // Throws `SchemaMismatch` on any difference from the fixture, indexes included.
    await verifier.migrateAndValidate(db, 2);

    await db.close();
  });

  test('carries v1 settings rows across the upgrade untouched', () async {
    final schema = await verifier.schemaAt(1);

    // Raw SQL on the raw handle: the database is still v1, and `GPAppDatabase` describes the current schema.
    schema.rawDatabase.execute("INSERT INTO settings (key, value, updated_at) VALUES ('locale.selected', 'vi', 1757800000000)");

    final db = GPAppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);

    final row = await (db.select(db.settingsTable)..where((t) => t.key.equals('locale.selected'))).getSingle();
    expect(row.value, 'vi');
    expect(row.updatedAt, 1757800000000);

    await db.close();
  });

  test('leaves the new accounts table present and empty after the upgrade', () async {
    final connection = await verifier.startAt(1);
    final db = GPAppDatabase.forTesting(connection);

    await verifier.migrateAndValidate(db, 2);

    // `migrateAndValidate` checks shape only: a migration that also seeded a row would pass it.
    expect(await db.select(db.accountsTable).get(), isEmpty);

    await db.close();
  });

  test('creates the accounts index on the upgrade path, not just on a fresh install', () async {
    final connection = await verifier.startAt(1);
    final db = GPAppDatabase.forTesting(connection);

    await verifier.migrateAndValidate(db, 2);

    // Also covered by `migrateAndValidate`; stated on its own because a missing index changes no query result, only its cost.
    final indexes = await db.customSelect("SELECT name FROM sqlite_schema WHERE type = 'index' AND tbl_name = 'accounts'").get();

    expect(indexes.map((row) => row.read<String>('name')), contains('accounts_owner_id_is_archived'));

    await db.close();
  });

  test('migrates v2 → v3 into the schema a fresh v3 install has', () async {
    final connection = await verifier.startAt(2);
    final db = GPAppDatabase.forTesting(connection);

    await verifier.migrateAndValidate(db, 3);

    await db.close();
  });

  test('carries v2 accounts rows across the v3 upgrade untouched', () async {
    final schema = await verifier.schemaAt(2);

    // Raw SQL: the database is still v2.
    schema.rawDatabase.execute(
      'INSERT INTO accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version) '
      "VALUES ('a1', 'local', 'Ví tiền mặt', 'cash', 'VND', 1500000, 0, 1757800000000, 1757800000000, 1)",
    );

    final db = GPAppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);

    final row = await (db.select(db.accountsTable)..where((t) => t.id.equals('a1'))).getSingle();
    expect(row.name, 'Ví tiền mặt');
    expect(row.initialBalance, 1500000);

    await db.close();
  });

  test('leaves the new categories table present and empty after the upgrade', () async {
    final connection = await verifier.startAt(2);
    final db = GPAppDatabase.forTesting(connection);

    await verifier.migrateAndValidate(db, 3);

    // Empty on purpose: `CategorySeeder` seeds at launch, never in a migration.
    expect(await db.select(db.categoriesTable).get(), isEmpty);

    await db.close();
  });

  test('creates both categories indexes on the upgrade path', () async {
    final connection = await verifier.startAt(2);
    final db = GPAppDatabase.forTesting(connection);

    await verifier.migrateAndValidate(db, 3);

    final indexes = await db.customSelect("SELECT name FROM sqlite_schema WHERE type = 'index' AND tbl_name = 'categories'").get();
    final names = indexes.map((row) => row.read<String>('name'));

    expect(names, contains('categories_owner_id_type'));
    expect(names, contains('categories_owner_id_name_key'));

    await db.close();
  });

  test('walks every step for a device that skipped a release', () async {
    final connection = await verifier.startAt(1);
    final db = GPAppDatabase.forTesting(connection);

    await verifier.migrateAndValidate(db, 3);

    expect(await db.select(db.accountsTable).get(), isEmpty);
    expect(await db.select(db.categoriesTable).get(), isEmpty);

    await db.close();
  });

  group('v3 → v4 (transactions, W4 T3)', () {
    // Raw SQL: the database is still v3.
    Future<GPAppDatabase> upgradedFromV3WithParents() async {
      final schema = await verifier.schemaAt(3);
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
      await verifier.migrateAndValidate(db, 4);
      return db;
    }

    TransactionsTableCompanion expense({required String id, required String accountId}) => TransactionsTableCompanion.insert(
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

    test('migrates into the schema a fresh v4 install has', () async {
      final connection = await verifier.startAt(3);
      final db = GPAppDatabase.forTesting(connection);

      // Covers the foreign keys and the CHECKs too: they are part of the `CREATE TABLE`.
      await verifier.migrateAndValidate(db, 4);

      await db.close();
    });

    test('carries v3 accounts and categories across untouched, and adds an empty transactions table', () async {
      final db = await upgradedFromV3WithParents();

      expect((await db.select(db.accountsTable).getSingle()).initialBalance, 1500000);
      expect((await db.select(db.categoriesTable).getSingle()).nameKey, 'category.food');
      expect(await db.select(db.transactionsTable).get(), isEmpty);

      await db.close();
    });

    test('creates all four transactions indexes on the upgrade path', () async {
      final connection = await verifier.startAt(3);
      final db = GPAppDatabase.forTesting(connection);

      await verifier.migrateAndValidate(db, 4);

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
      final db = await upgradedFromV3WithParents();

      await db.into(db.transactionsTable).insert(expense(id: 't1', accountId: 'a1'));
      await expectLater(
        db.into(db.transactionsTable).insert(expense(id: 't2', accountId: 'a-ghost')),
        throwsA(isA<SqliteException>().having((e) => e.message, 'message', contains('FOREIGN KEY constraint failed'))),
      );

      await db.close();
    });

    test('walks v2 → v4 and v1 → v4 for devices that skipped releases', () async {
      for (final from in [2, 1]) {
        final connection = await verifier.startAt(from);
        final db = GPAppDatabase.forTesting(connection);

        await verifier.migrateAndValidate(db, 4);

        expect(await db.select(db.transactionsTable).get(), isEmpty, reason: 'from v$from');

        await db.close();
      }
    });
  });
}
