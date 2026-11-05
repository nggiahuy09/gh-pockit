import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/database_too_new_exception.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;

late SchemaVerifier _verifier;

void main() {
  // The fixtures are the committed `drift_schemas/` dumps and the typed `vN` classes generated from them by the commands in CLAUDE.md §9.
  // A row for a database still at vN goes through `vN`, never through `GPAppDatabase`, which describes the current schema.

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
    await _writeAt(v1.DatabaseAtV1(schema.newConnection()), (old) => old.into(old.settings).insert(_v1Locale));

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
    await _writeAt(v2.DatabaseAtV2(schema.newConnection()), (old) => old.into(old.accounts).insert(_v2Cash));

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

  group('v1 → v5 with rows written at every version', () {
    // One file, upgraded a version at a time, each version writing the entity it introduced through its own typed fixture. The rows are read
    // back at the version that wrote them, and must come out of v5 the same, column for column.

    test('every row written along the way reaches v5 unchanged', () async {
      final schema = await _verifier.schemaAt(1);
      final written = <String, List<Map<String, Object?>>>{};

      await _writeAt(v1.DatabaseAtV1(schema.newConnection()), (old) async {
        await old.batch((batch) => batch.insertAll(old.settings, _chainSettings));
        written['settings'] = _json(await old.select(old.settings).get());
      });
      await _migrateTo(schema.newConnection(), 2);

      await _writeAt(v2.DatabaseAtV2(schema.newConnection()), (old) async {
        await old.batch((batch) => batch.insertAll(old.accounts, _chainAccounts));
        written['accounts'] = _json(await old.select(old.accounts).get());
      });
      await _migrateTo(schema.newConnection(), 3);

      await _writeAt(v3.DatabaseAtV3(schema.newConnection()), (old) async {
        await old.batch((batch) => batch.insertAll(old.categories, _chainCategories));
        written['categories'] = _json(await old.select(old.categories).get());
      });
      await _migrateTo(schema.newConnection(), 4);

      await _writeAt(v4.DatabaseAtV4(schema.newConnection()), (old) async {
        await old.batch((batch) => batch.insertAll(old.transactions, _chainTransactions));
        written['transactions'] = _json(await old.select(old.transactions).get());
      });
      await _migrateTo(schema.newConnection(), 5);

      final now = v5.DatabaseAtV5(schema.newConnection());
      expect(_json(await now.select(now.settings).get()), unorderedEquals(written['settings']!));
      expect(_json(await now.select(now.accounts).get()), unorderedEquals(written['accounts']!));
      expect(_json(await now.select(now.categories).get()), unorderedEquals(written['categories']!));
      expect(_json(await now.select(now.transactions).get()), unorderedEquals(written['transactions']!));
      await now.close();
    });

    test('the app reads the upgraded file: rows decode, balances add up, nothing dangles', () async {
      final schema = await _verifier.schemaAt(1);
      await _writeAt(v1.DatabaseAtV1(schema.newConnection()), (old) => old.batch((batch) => batch.insertAll(old.settings, _chainSettings)));
      await _migrateTo(schema.newConnection(), 2);
      await _writeAt(v2.DatabaseAtV2(schema.newConnection()), (old) => old.batch((batch) => batch.insertAll(old.accounts, _chainAccounts)));
      await _migrateTo(schema.newConnection(), 3);
      await _writeAt(v3.DatabaseAtV3(schema.newConnection()), (old) => old.batch((batch) => batch.insertAll(old.categories, _chainCategories)));
      await _migrateTo(schema.newConnection(), 4);
      await _writeAt(v4.DatabaseAtV4(schema.newConnection()), (old) => old.batch((batch) => batch.insertAll(old.transactions, _chainTransactions)));

      final db = GPAppDatabase.forTesting(schema.newConnection());
      await _verifier.migrateAndValidate(db, 5);

      // Through the app's own row classes, so an `INTEGER` flag or a NULL the mapping does not expect would throw here.
      final accounts = {for (final row in await db.select(db.accountsTable).get()) row.id: row};
      expect(accounts['a-old']!.isArchived, isTrue);
      expect(accounts['a-old']!.initialBalance, 1000000000000, reason: 'past 32 bits');
      expect(accounts['a-closed']!.deletedAt, 1760000000000);
      expect((await db.select(db.transactionsTable).get()).map((row) => row.note), contains('Phở bò "đặc biệt"\nquán cô Ba'));

      final balances = await TransactionDao(db).watchAccountBalances('local').first;
      expect(
        {for (final row in balances) row.account.id: row.balanceMinor},
        {
          'a-cash': 1500000 - 125000 - 300000 - 20000,
          'a-wallet': 300000,
          'a-bank': 12345 + 250000,
          'a-card': -2500000 - 45000,
        },
      );

      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect((await db.customSelect('PRAGMA integrity_check').getSingle()).read<String>('integrity_check'), 'ok');

      await db.close();
    });
  });

  group('a file from a newer release (ADR-0030)', () {
    // `user_version = 6` plus a table this build has never heard of: what a later release, a TestFlight build or a backup restored from a
    // newer phone leaves behind.

    test('is refused before any statement, and left exactly as found', () async {
      final schema = await _verifier.schemaAt(5);
      await _writeAt(v5.DatabaseAtV5(schema.newConnection()), (old) => old.into(old.accounts).insert(_v5Cash));
      schema.rawDatabase
        ..execute('CREATE TABLE budgets (id TEXT NOT NULL PRIMARY KEY)')
        ..userVersion = 6;
      final before = schema.rawDatabase.select(_schemaSql).map((row) => row['sql']).toList();

      // Twice: a refused open must not leave anything that lets the next one through.
      for (var attempt = 1; attempt <= 2; attempt++) {
        await expectLater(
          _open(schema.newConnection()),
          throwsA(isA<GPDatabaseTooNewException>().having((e) => e.fileVersion, 'fileVersion', 6).having((e) => e.appVersion, 'appVersion', 5)),
          reason: 'attempt $attempt',
        );
      }

      // Before the guard, drift wrote `user_version = 5` over a schema it did not know.
      expect(schema.rawDatabase.userVersion, 6);
      expect(schema.rawDatabase.select(_schemaSql).map((row) => row['sql']).toList(), before);
      expect(schema.rawDatabase.select('SELECT name FROM accounts').single['name'], 'Ví tiền mặt');
    });
  });

  group('a migration that dies part-way (ADR-0029)', () {
    // `_fault` takes the name of the last index the v4 step creates, so the step fails after everything before it ran — the state a kill
    // there leaves. Dropping it afterwards is the next launch, where whatever killed the app is gone.

    test('a failed step leaves the database at the version before it, with nothing of the step behind', () async {
      final schema = await _verifier.schemaAt(3);
      schema.rawDatabase.execute(_fault);
      await _writeAt(v3.DatabaseAtV3(schema.newConnection()), (old) => old.into(old.accounts).insert(_v3Cash));

      await expectLater(_open(schema.newConnection()), throwsA(_faultHit));

      expect(schema.rawDatabase.userVersion, 3);
      expect(_objectsOutsideFault(schema.rawDatabase.select(_schemaObjects)), isNot(contains(startsWith('transactions'))));
      // Through `v3`: opening `GPAppDatabase` again would migrate again.
      final old = v3.DatabaseAtV3(schema.newConnection());
      expect((await old.select(old.accounts).getSingle()).name, 'Ví tiền mặt');
      await old.close();
    });

    test('the next launch runs the failed step again in full', () async {
      final schema = await _verifier.schemaAt(3);
      schema.rawDatabase.execute(_fault);
      await _writeAt(v3.DatabaseAtV3(schema.newConnection()), (old) => old.into(old.accounts).insert(_v3Cash));
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
      schema.rawDatabase.execute(_fault);
      await _writeAt(v1.DatabaseAtV1(schema.newConnection()), (old) => old.into(old.settings).insert(_v1Locale));

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
const _schemaSql = "SELECT sql FROM sqlite_schema WHERE name NOT LIKE 'sqlite_%' ORDER BY name";

final Matcher _faultHit = isA<SqliteException>().having((e) => e.message, 'message', contains('transactions_category_id_occurred_at_id already exists'));

/// What the bootstrap does first: open, which is where drift migrates.
Future<void> _open(QueryExecutor executor) async {
  final db = GPAppDatabase.forTesting(executor);
  try {
    await db.open();
  } finally {
    await db.close();
  }
}

List<String> _objectsOutsideFault(Iterable<Map<String, Object?>> rows) => [
  for (final row in rows)
    if (row['name'] case final String name when name != 'fault' && name != 'transactions_category_id_occurred_at_id') name,
];

/// Two accounts, an expense, a transfer between them and a tombstone, written at v4.
Future<GPAppDatabase> _upgradedFromV4WithTransactions() async {
  final schema = await _verifier.schemaAt(4);
  await _writeAt(v4.DatabaseAtV4(schema.newConnection()), (old) async {
    await old.batch((batch) {
      batch
        ..insertAll(old.accounts, [_v4Account('a1', 'Ví tiền mặt', 'cash', 1500000), _v4Account('a2', 'Ví điện tử', 'e_wallet', 0)])
        ..insertAll(old.transactions, [
          _v4Transaction('t1', 'expense', 'a1', 125000, occurredAt: 1790573400000),
          _v4Transaction('t2', 'transfer', 'a1', 300000, occurredAt: 1790573500000, destinationAccountId: 'a2'),
          _v4Transaction('t3', 'expense', 'a2', 99000, occurredAt: 1790573600000, deletedAt: 1790573700000),
        ]);
    });
  });

  final db = GPAppDatabase.forTesting(schema.newConnection());
  await _verifier.migrateAndValidate(db, 5);
  return db;
}

Future<GPAppDatabase> _upgradedFromV3WithParents() async {
  final schema = await _verifier.schemaAt(3);
  await _writeAt(v3.DatabaseAtV3(schema.newConnection()), (old) async {
    await old.into(old.accounts).insert(_v3Cash);
    await old
        .into(old.categories)
        .insert(
          v3.CategoriesCompanion.insert(
            id: 'c1',
            ownerId: 'local',
            nameKey: const Value('category.food'),
            type: 'expense',
            isSystem: 1,
            createdAt: 1757800000000,
            updatedAt: 1757800000000,
            version: 1,
          ),
        );
  });

  final db = GPAppDatabase.forTesting(schema.newConnection());
  await _verifier.migrateAndValidate(db, 4);
  return db;
}

Future<void> _migrateTo(QueryExecutor connection, int version) async {
  final db = GPAppDatabase.forTesting(connection);
  await _verifier.migrateAndValidate(db, version);
  await db.close();
}

List<Map<String, Object?>> _json(List<DataClass> rows) => [for (final row in rows) row.toJson()];

final _chainSettings = [
  v1.SettingsCompanion.insert(key: 'locale.selected', value: 'vi', updatedAt: 1757800000000),
  v1.SettingsCompanion.insert(key: 'test.unicode', value: "Tiếng Việt có dấu — ✓ 'quoted'", updatedAt: 1757800000001),
];

final List<v2.AccountsCompanion> _chainAccounts = [
  _chainAccount('a-cash', 'Ví tiền mặt', 'cash', 1500000),
  _chainAccount('a-wallet', 'Ví điện tử', 'e_wallet', 0),
  _chainAccount('a-bank', 'Vietcombank USD', 'bank', 12345, currencyCode: 'USD'),
  _chainAccount('a-card', 'Thẻ tín dụng', 'credit_card', -2500000, version: 3, updatedAt: 1759000000000),
  _chainAccount('a-old', 'Heo đất', 'other', 1000000000000, isArchived: 1),
  _chainAccount('a-closed', 'Tài khoản đã đóng', 'bank', 0, deletedAt: 1760000000000),
];

final List<v3.CategoriesCompanion> _chainCategories = [
  _chainCategory('c-food', 'expense', nameKey: 'category.food', isSystem: 1),
  _chainCategory('c-salary', 'income', nameKey: 'category.salary', isSystem: 1),
  _chainCategory('c-coffee', 'expense', name: 'Cà phê ☕', iconKey: 'coffee', colorKey: 'amber'),
  _chainCategory('c-gone', 'expense', name: 'Đồ cũ', deletedAt: 1760000000000),
];

final List<v4.TransactionsCompanion> _chainTransactions = [
  _chainTransaction('t-food', 'expense', 'a-cash', 125000, categoryId: 'c-food', note: 'Phở bò "đặc biệt"\nquán cô Ba'),
  _chainTransaction('t-salary', 'income', 'a-bank', 250000, currencyCode: 'USD', categoryId: 'c-salary'),
  _chainTransaction('t-coffee', 'expense', 'a-card', 45000, categoryId: 'c-coffee'),
  _chainTransaction('t-transfer', 'transfer', 'a-cash', 300000, destinationAccountId: 'a-wallet'),
  _chainTransaction('t-loose', 'expense', 'a-cash', 20000),
  _chainTransaction('t-gone', 'expense', 'a-cash', 99000, categoryId: 'c-gone', deletedAt: 1790600000000),
];

v2.AccountsCompanion _chainAccount(
  String id,
  String name,
  String type,
  int initialBalance, {
  String currencyCode = 'VND',
  int isArchived = 0,
  int version = 1,
  int updatedAt = 1757800000000,
  int? deletedAt,
}) => v2.AccountsCompanion.insert(
  id: id,
  ownerId: 'local',
  name: name,
  type: type,
  currencyCode: currencyCode,
  initialBalance: initialBalance,
  isArchived: isArchived,
  createdAt: 1757800000000,
  updatedAt: updatedAt,
  version: version,
  deletedAt: Value(deletedAt),
);

v3.CategoriesCompanion _chainCategory(String id, String type, {String? nameKey, String? name, String? iconKey, String? colorKey, int isSystem = 0, int? deletedAt}) =>
    v3.CategoriesCompanion.insert(
      id: id,
      ownerId: 'local',
      nameKey: Value(nameKey),
      name: Value(name),
      type: type,
      iconKey: Value(iconKey),
      colorKey: Value(colorKey),
      isSystem: isSystem,
      createdAt: 1758000000000,
      updatedAt: deletedAt ?? 1758000000000,
      version: deletedAt == null ? 1 : 2,
      deletedAt: Value(deletedAt),
    );

v4.TransactionsCompanion _chainTransaction(
  String id,
  String type,
  String accountId,
  int amountMinor, {
  String currencyCode = 'VND',
  String? destinationAccountId,
  String? categoryId,
  String? note,
  int? deletedAt,
}) => v4.TransactionsCompanion.insert(
  id: id,
  ownerId: 'local',
  type: type,
  accountId: accountId,
  destinationAccountId: Value(destinationAccountId),
  categoryId: Value(categoryId),
  amountMinor: amountMinor,
  currencyCode: currencyCode,
  occurredAt: 1790573400000,
  note: Value(note),
  createdAt: 1790573400000,
  updatedAt: deletedAt ?? 1790573400000,
  version: deletedAt == null ? 1 : 2,
  deletedAt: Value(deletedAt),
  syncStatus: 'pending',
);

/// Opens [db] — a generated `DatabaseAtVN` over a file already at vN, so nothing migrates — writes, and closes it.
Future<void> _writeAt<D extends GeneratedDatabase>(D db, Future<void> Function(D old) write) async {
  try {
    await write(db);
  } finally {
    await db.close();
  }
}

final _v1Locale = v1.SettingsCompanion.insert(key: 'locale.selected', value: 'vi', updatedAt: 1757800000000);

final _v2Cash = v2.AccountsCompanion.insert(
  id: 'a1',
  ownerId: 'local',
  name: 'Ví tiền mặt',
  type: 'cash',
  currencyCode: 'VND',
  initialBalance: 1500000,
  isArchived: 0,
  createdAt: 1757800000000,
  updatedAt: 1757800000000,
  version: 1,
);

final _v5Cash = v5.AccountsCompanion.insert(
  id: 'a1',
  ownerId: 'local',
  name: 'Ví tiền mặt',
  type: 'cash',
  currencyCode: 'VND',
  initialBalance: 1500000,
  isArchived: 0,
  createdAt: 1757800000000,
  updatedAt: 1757800000000,
  version: 1,
);

final _v3Cash = v3.AccountsCompanion.insert(
  id: 'a1',
  ownerId: 'local',
  name: 'Ví tiền mặt',
  type: 'cash',
  currencyCode: 'VND',
  initialBalance: 1500000,
  isArchived: 0,
  createdAt: 1757800000000,
  updatedAt: 1757800000000,
  version: 1,
);

v4.AccountsCompanion _v4Account(String id, String name, String type, int initialBalance) => v4.AccountsCompanion.insert(
  id: id,
  ownerId: 'local',
  name: name,
  type: type,
  currencyCode: 'VND',
  initialBalance: initialBalance,
  isArchived: 0,
  createdAt: 1757800000000,
  updatedAt: 1757800000000,
  version: 1,
);

v4.TransactionsCompanion _v4Transaction(String id, String type, String accountId, int amountMinor, {required int occurredAt, String? destinationAccountId, int? deletedAt}) =>
    v4.TransactionsCompanion.insert(
      id: id,
      ownerId: 'local',
      type: type,
      accountId: accountId,
      destinationAccountId: Value(destinationAccountId),
      amountMinor: amountMinor,
      currencyCode: 'VND',
      occurredAt: occurredAt,
      createdAt: occurredAt,
      updatedAt: deletedAt ?? occurredAt,
      version: 1,
      deletedAt: Value(deletedAt),
      syncStatus: 'pending',
    );

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
