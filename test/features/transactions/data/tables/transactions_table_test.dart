// `isNull` is both a drift SQL predicate and a matcher; this file wants the matcher.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

/// The constraints on `transactions` that are decisions rather than drift defaults (W4 T3, ADR-0009).
///
/// The §6 column set is the same as `accounts` and is not re-asserted column by column. What is: every CHECK refuses the row it exists for, every foreign
/// key refuses a dangling id, what was deliberately *not* constrained stays unconstrained, and the four indexes really serve the order the list reads in.
/// Each test fails if a later edit quietly relaxes — or quietly tightens — one of them.
void main() {
  late GPAppDatabase db;

  const occurredAt = 1790573400000; // 2026-09-28 05:30 UTC
  const now = 1790575200000; // 2026-09-28 06:00 UTC

  setUp(() async {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());

    // The parents every foreign key below points at. Inserted through the generated companions: this file is about `transactions`, not about them.
    for (final id in ['acc-cash', 'acc-bank']) {
      await db
          .into(db.accountsTable)
          .insert(
            AccountsTableCompanion.insert(
              id: id,
              ownerId: localOwnerId,
              name: id,
              type: 'cash',
              currencyCode: 'VND',
              initialBalance: 0,
              isArchived: false,
              createdAt: now,
              updatedAt: now,
              version: 1,
            ),
          );
    }
    await db
        .into(db.categoriesTable)
        .insert(
          CategoriesTableCompanion.insert(
            id: 'cat-food',
            ownerId: localOwnerId,
            nameKey: const Value('category.food'),
            type: 'expense',
            isSystem: true,
            createdAt: now,
            updatedAt: now,
            version: 1,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  TransactionsTableCompanion transaction({
    String id = 'tx-1',
    String type = 'expense',
    String accountId = 'acc-cash',
    String? destinationAccountId,
    String? categoryId = 'cat-food',
    int amountMinor = 125000,
    String currencyCode = 'VND',
    int occurredAt = occurredAt,
    String? note,
    String syncStatus = 'pending',
  }) => TransactionsTableCompanion.insert(
    id: id,
    ownerId: localOwnerId,
    type: type,
    accountId: accountId,
    destinationAccountId: Value(destinationAccountId),
    categoryId: Value(categoryId),
    amountMinor: amountMinor,
    currencyCode: currencyCode,
    occurredAt: occurredAt,
    note: Value(note),
    createdAt: now,
    updatedAt: now,
    version: 1,
    syncStatus: syncStatus,
  );

  TransactionsTableCompanion transfer({String? destinationAccountId = 'acc-bank', String? categoryId}) =>
      transaction(type: TransactionType.transfer.storageValue, destinationAccountId: destinationAccountId, categoryId: categoryId);

  Future<void> insert(TransactionsTableCompanion row) => db.into(db.transactionsTable).insert(row);

  Matcher refusedBy(String constraint) => throwsA(isA<SqliteException>().having((e) => e.message, 'message', contains(constraint)));

  group('stores', () {
    test('every column, with the nullable ones null and deleted_at null on a live row', () async {
      await insert(transaction());

      final row = await db.select(db.transactionsTable).getSingle();

      expect(row.id, 'tx-1');
      expect(row.ownerId, localOwnerId);
      expect(row.type, 'expense');
      expect(row.accountId, 'acc-cash');
      expect(row.destinationAccountId, isNull);
      expect(row.categoryId, 'cat-food');
      expect(row.amountMinor, 125000);
      expect(row.currencyCode, 'VND');
      expect(row.occurredAt, occurredAt);
      expect(row.note, isNull);
      expect(row.createdAt, now);
      expect(row.updatedAt, now);
      expect(row.version, 1);
      // Null, not 0 — a tombstone column that defaulted to an epoch would be a row deleted in 1970.
      expect(row.deletedAt, isNull);
      expect(row.syncStatus, 'pending');
    });

    test('a transfer: a destination, and no category', () async {
      await insert(transfer());

      final row = await db.select(db.transactionsTable).getSingle();

      expect(row.type, 'transfer');
      expect(row.accountId, 'acc-cash');
      expect(row.destinationAccountId, 'acc-bank');
      expect(row.categoryId, isNull);
    });

    test('the amount as an integer, never a real', () async {
      await insert(transaction(amountMinor: 1));

      // Raw SQL, so the assertion is about what SQLite holds rather than what the row class casts it to (same reason as `accounts_table_test.dart`).
      final raw = await db.customSelect('SELECT typeof(amount_minor) AS t FROM transactions').getSingle();

      expect(raw.read<String>('t'), 'integer');
    });
  });

  group('refuses, by CHECK', () {
    test('an amount of zero or less — the type is the sign', () async {
      await expectLater(insert(transaction(amountMinor: 0)), refusedBy('CHECK constraint failed'));
      await expectLater(insert(transaction(id: 'tx-2', amountMinor: -125000)), refusedBy('CHECK constraint failed'));
    });

    test('a currency code that is not three characters', () async {
      await expectLater(insert(transaction(currencyCode: 'VN')), refusedBy('CHECK constraint failed'));
    });

    test('a transfer with no destination', () async {
      // Built from `TransactionType.transfer.storageValue`, not a typed `'transfer'`: the table's CHECK names the literal, and this is what fails if the two
      // ever drift apart.
      await expectLater(insert(transfer(destinationAccountId: null)), refusedBy('CHECK constraint failed'));
    });

    test('a destination on anything that is not a transfer', () async {
      await expectLater(insert(transaction(destinationAccountId: 'acc-bank')), refusedBy('CHECK constraint failed'));
      await expectLater(insert(transaction(id: 'tx-2', type: 'income', destinationAccountId: 'acc-bank')), refusedBy('CHECK constraint failed'));
    });

    test('a transfer into the account it leaves', () async {
      await expectLater(insert(transfer(destinationAccountId: 'acc-cash')), refusedBy('CHECK constraint failed'));
    });

    test('a transfer filed under a category', () async {
      await expectLater(insert(transfer(categoryId: 'cat-food')), refusedBy('CHECK constraint failed'));
    });

    test('the transfer shape on a raw write too, not only through the companion', () async {
      // The path the pull of W14 may take. A CHECK lives in the `CREATE TABLE`, so bypassing Dart bypasses nothing.
      await expectLater(
        db.customStatement(
          'INSERT INTO transactions (id, owner_id, type, account_id, amount_minor, currency_code, occurred_at, created_at, updated_at, version, sync_status) '
          "VALUES ('tx-raw', 'local', 'transfer', 'acc-cash', 1, 'VND', 0, 0, 0, 1, 'pending')",
        ),
        refusedBy('CHECK constraint failed'),
      );
    });
  });

  group('refuses, by foreign key', () {
    test('an account that does not exist', () async {
      await expectLater(insert(transaction(accountId: 'acc-ghost')), refusedBy('FOREIGN KEY constraint failed'));
    });

    test('a destination that does not exist', () async {
      await expectLater(insert(transfer(destinationAccountId: 'acc-ghost')), refusedBy('FOREIGN KEY constraint failed'));
    });

    test('a category that does not exist', () async {
      await expectLater(insert(transaction(categoryId: 'cat-ghost')), refusedBy('FOREIGN KEY constraint failed'));
    });

    test('but not a soft-deleted parent, which is still a row', () async {
      // ADR-0010 relies on this: sync can leave a live transaction on a tombstoned account, and deleting a category keeps its transactions pointing at the
      // tombstone. A foreign key that treated soft-deleted parents as missing would make both states unstorable.
      await (db.update(db.accountsTable)..where((t) => t.id.equals('acc-cash'))).write(const AccountsTableCompanion(deletedAt: Value(now)));
      await (db.update(db.categoriesTable)..where((t) => t.id.equals('cat-food'))).write(const CategoriesTableCompanion(deletedAt: Value(now)));

      await insert(transaction());

      expect(await db.select(db.transactionsTable).get(), hasLength(1));
    });
  });

  group('deliberately does not constrain', () {
    test('the vocabulary of type and sync_status — the mapper refuses unknown values on read', () async {
      // No `CHECK (type IN (...))` (ADR-0009): a new type would then be a table rebuild. The row below is storable, and it is the mapper at T6 that turns
      // it into an unreadable row (ADR-0011) rather than a guess.
      await insert(transaction(type: 'refund', syncStatus: 'something-newer'));

      final row = await db.select(db.transactionsTable).getSingle();

      expect(row.type, 'refund');
      expect(row.syncStatus, 'something-newer');
    });

    test('a note of any length — that limit is a domain rule', () async {
      await insert(transaction(note: 'a' * 5000));

      expect((await db.select(db.transactionsTable).getSingle()).note, hasLength(5000));
    });
  });

  test('requires every sync column — no SQL default fills one in', () async {
    // Raw SQL, because the companion makes this a compile error. A default `sync_status` would be a sync state nobody wrote, and a default `version` a
    // base version the server never issued.
    await expectLater(
      db.customStatement(
        'INSERT INTO transactions (id, owner_id, type, account_id, amount_minor, currency_code, occurred_at, created_at, updated_at, version) '
        "VALUES ('tx-raw', 'local', 'expense', 'acc-cash', 1, 'VND', 0, 0, 0, 1)",
      ),
      refusedBy('NOT NULL constraint failed: transactions.sync_status'),
    );
    await expectLater(
      db.customStatement(
        'INSERT INTO transactions (id, owner_id, type, account_id, amount_minor, currency_code, occurred_at, created_at, updated_at, sync_status) '
        "VALUES ('tx-raw', 'local', 'expense', 'acc-cash', 1, 'VND', 0, 0, 0, 'pending')",
      ),
      refusedBy('NOT NULL constraint failed: transactions.version'),
    );
  });

  group('serves the list order from an index, with no sort step', () {
    // One query per way the list is narrowed, each in the order ADR-0011 fixes. The assertion is on the plan, not on timing: `USING INDEX <name>` says the
    // rows come off that index, and the absence of `TEMP B-TREE` says nothing had to be sorted afterwards — which is what keeps `LIMIT 50` cheap at 50k
    // rows. W8 measures the cost; this pins the shape.
    const order = 'ORDER BY occurred_at DESC, id DESC LIMIT 50';

    final cases = <String, (String, String)>{
      'by owner': ('owner_id', 'transactions_owner_id_occurred_at_id'),
      'by account': ('account_id', 'transactions_account_id_occurred_at_id'),
      'by destination account': ('destination_account_id', 'transactions_destination_account_id_occurred_at_id'),
      'by category': ('category_id', 'transactions_category_id_occurred_at_id'),
    };

    for (final MapEntry(key: label, value: (column, index)) in cases.entries) {
      test(label, () async {
        final plan = await db
            .customSelect('EXPLAIN QUERY PLAN SELECT * FROM transactions WHERE $column = ? AND deleted_at IS NULL $order', variables: [Variable.withString('x')])
            .get();
        final details = plan.map((row) => row.read<String>('detail')).join('\n');

        expect(details, contains('USING INDEX $index'));
        expect(details, isNot(contains('TEMP B-TREE')));
      });
    }
  });
}
