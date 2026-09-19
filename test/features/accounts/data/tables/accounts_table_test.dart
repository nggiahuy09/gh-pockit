// `isNull` exists in both drift (the SQL predicate) and matcher (the test expectation), and this file needs the matcher. The SQL side is still reachable
// as the `.isNull()` method on a column, which is what the soft-delete query below uses.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';

/// The first synced table under test (W2 T3).
///
/// `settings` is already covered in `test/core/database/database_test.dart`, and what is asserted there — a write is visible to a read, a `watch()` re-emits
/// — is not re-asserted here; Drift does not behave differently per table. What this file covers is the part of `accounts` that is a *decision*: the columns
/// §6 demands of a synced entity, the constraints that were chosen, and the ones that were deliberately not chosen. Each test below fails if a later edit
/// quietly relaxes one.
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
    // 1.500.000 ₫ as minor units, and VND has exponent 0 — so the integer is the whole dong amount, not a scaled one (golden rule 2).
    expect(row.initialBalance, 1500000);
    expect(row.isArchived, false);
    expect(row.createdAt, 1757800000000);
    expect(row.updatedAt, 1757800000000);
    expect(row.version, 1);
    // Null, not 0. A tombstone column that defaults to an epoch is a row deleted on 1 January 1970.
    expect(row.deletedAt, isNull);
  });

  test('stores money as an int, never a double', () async {
    await db.into(db.accountsTable).insert(account(initialBalance: -250000));

    // Read through raw SQL so the assertion is about what SQLite holds, not about what the generated row class casts it to. A REAL column would still
    // surface as an `int` through drift's mapping and this test would be worthless.
    final raw = await db.customSelect('SELECT typeof(initial_balance) AS t, initial_balance AS v FROM accounts').getSingle();

    expect(raw.read<String>('t'), 'integer');
    // Negative balances are legal — a credit card opens overdrawn.
    expect(raw.read<int>('v'), -250000);
  });

  test('rejects a currency code that is not three characters', () async {
    // `currency_code` decides how `initial_balance` is read (VND exponent 0, USD exponent 2), so a malformed code makes the integer beside it
    // un-interpretable rather than merely invalid — a storage-integrity concern, not a domain rule.
    await expectLater(
      db.into(db.accountsTable).insert(account(currencyCode: 'VN')),
      throwsA(isA<SqliteException>().having((e) => e.message, 'message', contains('CHECK constraint failed'))),
    );
  });

  test('enforces the currency code length in SQL, not only through the companion', () async {
    // The reason `check()` was chosen over `withLength`. `withLength` compiles to a Dart-side validator and leaves the column as a bare `TEXT NOT NULL` in
    // the schema, so the test above would pass while a raw write — a migration, or a raw upsert in P4's `RemoteChangeApplier` — stored `'VN'` happily. This
    // is the assertion that tells the two apart, and it fails the moment someone "simplifies" the column back.
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

    // Ids are minted client-side (golden rule 4, ADR-0002), so nothing server-side is left to catch a collision. The primary key is the only guard, and a
    // duplicate must fail loudly here rather than become two rows that sync fights over.
    await expectLater(
      db.into(db.accountsTable).insert(account(name: 'Khác')),
      throwsA(isA<SqliteException>()),
    );
  });

  test('requires every sync column — no SQL default fills one in', () async {
    // Raw SQL because the generated companion makes this a compile error, which is the point: the `required` on `AccountsTableCompanion.insert` is not the
    // only thing holding the line. A migration, a `customStatement`, or a future raw upsert in the sync applier bypasses Dart entirely, and `version`
    // silently defaulting to 1 would be a row claiming a base version the server never issued.
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

    // Still on disk — golden rule 5. A hard DELETE here would be a row the server never learns is gone, and P4's tombstone pull would have nothing to
    // reconcile against.
    final all = await db.select(db.accountsTable).get();
    expect(all, hasLength(1));
    expect(all.single.deletedAt, 1757900000000);

    // And invisible to the filter every DAO applies — audited across the codebase at W12 T3.
    final live = await (db.select(db.accountsTable)..where((t) => t.deletedAt.isNull())).get();
    expect(live, isEmpty);
  });

  test('archived is not deleted', () async {
    await db.into(db.accountsTable).insert(account(isArchived: true));

    final row = await db.select(db.accountsTable).getSingle();

    // Two different states with two different columns, asserted together because collapsing them is the tempting simplification: an archived account
    // vanishes from pickers but keeps its history and keeps syncing, while a deleted one is a tombstone.
    expect(row.isArchived, true);
    expect(row.deletedAt, isNull);
  });
}
