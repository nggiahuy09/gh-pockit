import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';

void main() {
  late GPAppDatabase db;

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  AccountsTableCompanion account({
    String id = 'a1',
    String name = 'Ví tiền mặt',
    String currencyCode = 'VND',
    int initialBalance = 1500000,
    bool isArchived = false,
    int version = 1,
  }) => AccountsTableCompanion.insert(
    id: id,
    ownerId: localOwnerId,
    name: name,
    type: 'cash',
    currencyCode: currencyCode,
    initialBalance: initialBalance,
    isArchived: isArchived,
    createdAt: 1757800000000,
    updatedAt: 1757800000000,
    version: version,
  );

  test('round-trips every column, with deleted_at null on a live row', () async {
    await db.into(db.accountsTable).insert(account());

    final row = await db.select(db.accountsTable).getSingle();

    expect(row.id, 'a1');
    expect(row.ownerId, localOwnerId);
    expect(row.name, 'Ví tiền mặt');
    expect(row.type, 'cash');
    expect(row.currencyCode, 'VND');
    expect(row.initialBalance, 1500000);
    expect(row.isArchived, false);
    expect(row.createdAt, 1757800000000);
    expect(row.updatedAt, 1757800000000);
    expect(row.version, 1);
    expect(row.deletedAt, isNull);
  });

  test('stores money as an int, never a double', () async {
    await db.into(db.accountsTable).insert(account(initialBalance: -250000));

    // Raw SQL: a REAL column would still surface as an `int` through drift's row class.
    final raw = await db.customSelect('SELECT typeof(initial_balance) AS t, initial_balance AS v FROM accounts').getSingle();

    expect(raw.read<String>('t'), 'integer');
    // Negative balances are legal — a credit card opens overdrawn.
    expect(raw.read<int>('v'), -250000);
  });

  test('rejects a currency code that is not three characters', () async {
    await expectLater(
      db.into(db.accountsTable).insert(account(currencyCode: 'VN')),
      throwsA(isA<SqliteException>().having((e) => e.message, 'message', contains('CHECK constraint failed'))),
    );
  });

  test('enforces the currency code length in SQL, not only through the companion', () async {
    // Raw SQL skips the companion: `withLength` would pass the test above yet leave the column a bare `TEXT NOT NULL`.
    await expectLater(
      db.customStatement(
        'INSERT INTO accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version) '
        "VALUES ('a3', 'local', 'Ví', 'cash', 'VN', 0, 0, 0, 0, 1)",
      ),
      throwsA(isA<SqliteException>().having((e) => e.message, 'message', contains('CHECK constraint failed'))),
    );
  });

  test('rejects a second row with the same id', () async {
    await db.into(db.accountsTable).insert(account());

    await expectLater(
      db.into(db.accountsTable).insert(account(name: 'Khác')),
      throwsA(isA<SqliteException>()),
    );
  });

  test('requires every sync column — no SQL default fills one in', () async {
    // Raw SQL: the companion's `required` makes this a compile error, but a migration or a raw upsert bypasses Dart.
    await expectLater(
      db.customStatement(
        'INSERT INTO accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at) '
        "VALUES ('a2', 'local', 'Ví', 'cash', 'VND', 0, 0, 0, 0)",
      ),
      throwsA(isA<SqliteException>().having((e) => e.message, 'message', contains('NOT NULL constraint failed'))),
    );
  });

  test('soft delete keeps the row and is visible to a deleted_at IS NULL filter', () async {
    await db.into(db.accountsTable).insert(account());

    await (db.update(db.accountsTable)..where((t) => t.id.equals('a1'))).write(
      const AccountsTableCompanion(deletedAt: Value(1757900000000), updatedAt: Value(1757900000000), version: Value(2)),
    );

    final all = await db.select(db.accountsTable).get();
    expect(all, hasLength(1));
    expect(all.single.deletedAt, 1757900000000);

    final live = await (db.select(db.accountsTable)..where((t) => t.deletedAt.isNull())).get();
    expect(live, isEmpty);
  });

  test('archived is not deleted', () async {
    await db.into(db.accountsTable).insert(account(isArchived: true));

    final row = await db.select(db.accountsTable).getSingle();

    expect(row.isArchived, true);
    expect(row.deletedAt, isNull);
  });
}
