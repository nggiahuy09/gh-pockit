import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';

void main() {
  const t0 = 1000;
  const t1 = 2000;
  const otherOwner = 'someone-else';

  late GPAppDatabase db;
  late TransactionDao dao;

  setUp(() async {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    dao = TransactionDao(db);

    Future<void> account(String id, {String ownerId = localOwnerId, String currencyCode = 'VND', bool isArchived = false}) => db
        .into(db.accountsTable)
        .insert(
          AccountsTableCompanion.insert(
            id: id,
            ownerId: ownerId,
            name: id,
            type: 'cash',
            currencyCode: currencyCode,
            initialBalance: 0,
            isArchived: isArchived,
            createdAt: t0,
            updatedAt: t0,
            version: 1,
          ),
        );

    await account('acc-cash');
    await account('acc-bank');
    await account('acc-usd', currencyCode: 'USD');
    await account('acc-archived', isArchived: true);
    await account('acc-theirs', ownerId: otherOwner);

    for (final id in ['cat-food', 'cat-rent']) {
      await db
          .into(db.categoriesTable)
          .insert(
            CategoriesTableCompanion.insert(
              id: id,
              ownerId: localOwnerId,
              nameKey: Value('category.$id'),
              type: 'expense',
              isSystem: true,
              createdAt: t0,
              updatedAt: t0,
              version: 1,
            ),
          );
    }
  });

  tearDown(() async {
    await db.close();
  });

  /// `syncStatus` is 'synced' on purpose, so every write test proves the DAO stamps 'pending' over it.
  TransactionsTableCompanion row({
    String id = 'tx-1',
    String ownerId = localOwnerId,
    String type = 'expense',
    String accountId = 'acc-cash',
    String? destinationAccountId,
    String? categoryId = 'cat-food',
    int amountMinor = 125000,
    int occurredAt = t0,
    String? note,
  }) => TransactionsTableCompanion.insert(
    id: id,
    ownerId: ownerId,
    type: type,
    accountId: accountId,
    destinationAccountId: Value(destinationAccountId),
    categoryId: Value(categoryId),
    amountMinor: amountMinor,
    currencyCode: 'VND',
    occurredAt: occurredAt,
    note: Value(note),
    createdAt: t0,
    updatedAt: t0,
    version: 1,
    syncStatus: 'synced',
  );

  TransactionsTableCompanion transfer({required String id, required String from, required String to, int occurredAt = t0}) =>
      row(id: id, type: 'transfer', accountId: from, destinationAccountId: to, categoryId: null, occurredAt: occurredAt);

  /// Not [TransactionDao.softDelete], which is itself under test; not `customStatement`, which does not tell drift the table changed, so no `watch()` would re-emit.
  Future<void> tombstone(String id) =>
      (db.update(db.transactionsTable)..where((t) => t.id.equals(id))).write(const TransactionsTableCompanion(deletedAt: Value(t1), updatedAt: Value(t1)));

  Future<List<String>> idsOf({
    int limit = 50,
    Set<String>? accountIds,
    Set<String>? categoryIds,
    Set<String>? types,
    int? fromMillis,
    int? toMillis,
  }) async {
    final rows = await dao
        .watchTransactions(localOwnerId, limit: limit, accountIds: accountIds, categoryIds: categoryIds, types: types, fromMillis: fromMillis, toMillis: toMillis)
        .first;

    return rows.map((r) => r.id).toList();
  }

  group('watchTransactions', () {
    test('emits a transaction written after it subscribed, with no refresh', () async {
      final emissions = <List<String>>[];
      final subscription = dao.watchTransactions(localOwnerId, limit: 50).listen((rows) => emissions.add(rows.map((r) => r.id).toList()));

      // Yields to the event loop so the stream can deliver what is already queued.
      await pumpEventQueue();
      await dao.insertTransaction(row());
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions, [
        <String>[],
        ['tx-1'],
      ]);
    });

    test('re-emits on an update and on a soft delete', () async {
      await dao.insertTransaction(row());

      final emissions = <List<int>>[];
      final subscription = dao.watchTransactions(localOwnerId, limit: 50).listen((rows) => emissions.add(rows.map((r) => r.amountMinor).toList()));

      await pumpEventQueue();
      await dao.updateTransaction(
        'tx-1',
        baseVersion: 1,
        patch: const TransactionsTableCompanion(amountMinor: Value(95000)),
        now: t1,
      );
      await pumpEventQueue();
      await dao.softDelete('tx-1', now: t1);
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions, [
        [125000],
        [95000],
        <int>[],
      ]);
    });

    test('is scoped to one owner', () async {
      await dao.insertTransaction(row());
      await dao.insertTransaction(row(id: 'tx-theirs', ownerId: otherOwner, accountId: 'acc-theirs', categoryId: null));

      expect(await idsOf(), ['tx-1']);
    });

    test('never returns a soft-deleted row', () async {
      await dao.insertTransaction(row());
      await dao.insertTransaction(row(id: 'tx-2'));
      await tombstone('tx-1');

      expect(await idsOf(), ['tx-2']);
    });

    test('orders newest first, and by id — descending — among rows that share an instant', () async {
      // Inserted out of id order, so insertion (rowid) order would not pass.
      await dao.insertTransaction(row(id: 'tx-a'));
      await dao.insertTransaction(row(id: 'tx-c'));
      await dao.insertTransaction(row(id: 'tx-b'));
      await dao.insertTransaction(row(id: 'tx-new', occurredAt: t1));

      expect(await idsOf(), ['tx-new', 'tx-c', 'tx-b', 'tx-a']);
    });

    test('returns at most limit rows — the newest ones', () async {
      for (var i = 1; i <= 5; i++) {
        await dao.insertTransaction(row(id: 'tx-$i', occurredAt: t0 + i));
      }

      expect(await idsOf(limit: 3), ['tx-5', 'tx-4', 'tx-3']);
    });

    test('matches an account on either side of a transfer', () async {
      await dao.insertTransaction(row(id: 'tx-spent-cash', occurredAt: t0 + 3));
      await dao.insertTransaction(transfer(id: 'tx-bank-to-cash', from: 'acc-bank', to: 'acc-cash', occurredAt: t0 + 2));
      await dao.insertTransaction(row(id: 'tx-spent-bank', accountId: 'acc-bank', occurredAt: t0 + 1));

      expect(await idsOf(accountIds: {'acc-cash'}), ['tx-spent-cash', 'tx-bank-to-cash']);
      expect(await idsOf(accountIds: {'acc-bank'}), ['tx-bank-to-cash', 'tx-spent-bank']);
    });

    test('filters by category, leaving uncategorised rows out', () async {
      await dao.insertTransaction(row(id: 'tx-food'));
      await dao.insertTransaction(row(id: 'tx-rent', categoryId: 'cat-rent'));
      await dao.insertTransaction(row(id: 'tx-none', categoryId: null));

      expect(await idsOf(categoryIds: {'cat-food'}), ['tx-food']);
    });

    test('filters by type', () async {
      await dao.insertTransaction(row(id: 'tx-expense', occurredAt: t0 + 3));
      await dao.insertTransaction(row(id: 'tx-income', type: 'income', occurredAt: t0 + 2));
      await dao.insertTransaction(transfer(id: 'tx-transfer', from: 'acc-cash', to: 'acc-bank', occurredAt: t0 + 1));

      expect(await idsOf(types: {'expense', 'income'}), ['tx-expense', 'tx-income']);
      expect(await idsOf(types: {'transfer'}), ['tx-transfer']);
    });

    test('reads the range as [from, to) — from inclusive, to exclusive', () async {
      await dao.insertTransaction(row(id: 'tx-before', occurredAt: 100));
      await dao.insertTransaction(row(id: 'tx-at-from', occurredAt: 200));
      await dao.insertTransaction(row(id: 'tx-inside', occurredAt: 250));
      await dao.insertTransaction(row(id: 'tx-at-to', occurredAt: 300));

      expect(await idsOf(fromMillis: 200, toMillis: 300), ['tx-inside', 'tx-at-from']);
      expect(await idsOf(fromMillis: 300), ['tx-at-to']);
      expect(await idsOf(toMillis: 200), ['tx-before']);
    });

    test('ANDs every filter together', () async {
      await dao.insertTransaction(row(id: 'tx-match', occurredAt: 250));
      await dao.insertTransaction(row(id: 'tx-other-category', categoryId: 'cat-rent', occurredAt: 250));
      await dao.insertTransaction(row(id: 'tx-other-account', accountId: 'acc-bank', occurredAt: 250));
      await dao.insertTransaction(row(id: 'tx-out-of-range', occurredAt: 500));

      expect(await idsOf(accountIds: {'acc-cash'}, categoryIds: {'cat-food'}, types: {'expense'}, fromMillis: 200, toMillis: 300), ['tx-match']);
    });

    test('reads an empty set as SQL does — it matches nothing', () async {
      // The domain never sends one: `TransactionQuery` turns an empty set into no filter.
      await dao.insertTransaction(row());

      expect(await idsOf(accountIds: <String>{}), isEmpty);
      expect(await idsOf(), ['tx-1']);
    });
  });

  group('watchTransaction', () {
    test('emits the row, then null once it is soft-deleted', () async {
      await dao.insertTransaction(row());

      final emissions = <String?>[];
      final subscription = dao.watchTransaction(localOwnerId, 'tx-1').listen((r) => emissions.add(r?.id));

      await pumpEventQueue();
      await tombstone('tx-1');
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions, ['tx-1', null]);
    });

    test('emits null for an unknown id and never reaches across owners', () async {
      await dao.insertTransaction(row(id: 'tx-theirs', ownerId: otherOwner, accountId: 'acc-theirs', categoryId: null));

      expect(await dao.watchTransaction(localOwnerId, 'tx-missing').first, isNull);
      expect(await dao.watchTransaction(localOwnerId, 'tx-theirs').first, isNull);
    });
  });

  test('findById finds a tombstone, unlike every other read', () async {
    await dao.insertTransaction(row());
    await tombstone('tx-1');

    final found = await dao.findById('tx-1');

    expect(found, isNotNull);
    expect(found!.deletedAt, t1);
  });

  group('liveAccountCurrency', () {
    test("answers with the account's currency while it is live — archived included", () async {
      expect(await dao.liveAccountCurrency(localOwnerId, 'acc-cash'), 'VND');
      expect(await dao.liveAccountCurrency(localOwnerId, 'acc-usd'), 'USD');
      expect(await dao.liveAccountCurrency(localOwnerId, 'acc-archived'), 'VND');
    });

    test('answers null for a deleted account, an unknown one, or one of another owner', () async {
      await (db.update(db.accountsTable)..where((t) => t.id.equals('acc-bank'))).write(const AccountsTableCompanion(deletedAt: Value(t1)));

      expect(await dao.liveAccountCurrency(localOwnerId, 'acc-bank'), isNull);
      expect(await dao.liveAccountCurrency(localOwnerId, 'acc-missing'), isNull);
      expect(await dao.liveAccountCurrency(localOwnerId, 'acc-theirs'), isNull);
    });
  });

  group('hasLiveTransactions', () {
    test('is false for an account no transaction touches', () async {
      await dao.insertTransaction(row(accountId: 'acc-bank'));

      expect(await dao.hasLiveTransactions(localOwnerId, 'acc-cash'), isFalse);
    });

    test('is true for the account a transaction is on', () async {
      await dao.insertTransaction(row());

      expect(await dao.hasLiveTransactions(localOwnerId, 'acc-cash'), isTrue);
    });

    test("is true for a transfer's destination — the side a delete would silently strand", () async {
      await dao.insertTransaction(transfer(id: 'tx-1', from: 'acc-cash', to: 'acc-bank'));

      expect(await dao.hasLiveTransactions(localOwnerId, 'acc-bank'), isTrue);
    });

    test('is true for an archived account — archiving keeps the history', () async {
      await dao.insertTransaction(row(accountId: 'acc-archived'));

      expect(await dao.hasLiveTransactions(localOwnerId, 'acc-archived'), isTrue);
    });

    test('does not count a tombstone', () async {
      await dao.insertTransaction(row());
      await tombstone('tx-1');

      expect(await dao.hasLiveTransactions(localOwnerId, 'acc-cash'), isFalse);
    });

    test("does not count another owner's transaction — the `+` keeps the owner out of the index choice, not out of the WHERE", () async {
      await dao.insertTransaction(row(ownerId: otherOwner, accountId: 'acc-theirs', categoryId: null));

      expect(await dao.hasLiveTransactions(localOwnerId, 'acc-theirs'), isFalse);
      expect(await dao.hasLiveTransactions(otherOwner, 'acc-theirs'), isTrue);
    });
  });

  group('insertTransaction', () {
    test("stamps sync_status 'pending', whatever the companion carried", () async {
      await dao.insertTransaction(row());

      final stored = await db.select(db.transactionsTable).getSingle();

      expect(stored.syncStatus, TransactionDao.pendingSyncStatus);
      expect(stored.syncStatus, 'pending');
    });
  });

  group('updateTransaction', () {
    test("writes the patch, stamps updated_at and 'pending', and leaves version alone", () async {
      await dao.insertTransaction(row());
      await db.update(db.transactionsTable).write(const TransactionsTableCompanion(syncStatus: Value('synced')));

      final written = await dao.updateTransaction(
        'tx-1',
        baseVersion: 1,
        patch: const TransactionsTableCompanion(amountMinor: Value(95000), note: Value('Bún chả')),
        now: t1,
      );
      final stored = await db.select(db.transactionsTable).getSingle();

      expect(written, 1);
      expect(stored.amountMinor, 95000);
      expect(stored.note, 'Bún chả');
      expect(stored.updatedAt, t1);
      expect(stored.syncStatus, 'pending');
      expect(stored.version, 1);
      expect(stored.createdAt, t0);
    });

    test('writes nothing when the base version is stale', () async {
      await dao.insertTransaction(row());

      final written = await dao.updateTransaction(
        'tx-1',
        baseVersion: 2,
        patch: const TransactionsTableCompanion(amountMinor: Value(95000)),
        now: t1,
      );

      expect(written, 0);
      expect((await db.select(db.transactionsTable).getSingle()).amountMinor, 125000);
    });

    test('refuses a soft-deleted row', () async {
      await dao.insertTransaction(row());
      await tombstone('tx-1');

      final written = await dao.updateTransaction(
        'tx-1',
        baseVersion: 1,
        patch: const TransactionsTableCompanion(amountMinor: Value(95000)),
        now: t1,
      );

      expect(written, 0);
    });
  });

  group('softDelete', () {
    test("stamps deleted_at, updated_at and 'pending', leaving version alone", () async {
      await dao.insertTransaction(row());
      await db.update(db.transactionsTable).write(const TransactionsTableCompanion(syncStatus: Value('synced')));

      final written = await dao.softDelete('tx-1', now: t1);
      final stored = await db.select(db.transactionsTable).getSingle();

      expect(written, 1);
      expect(stored.deletedAt, t1);
      expect(stored.updatedAt, t1);
      expect(stored.syncStatus, 'pending');
      expect(stored.version, 1);
    });

    test('writes nothing the second time, or for an unknown id', () async {
      await dao.insertTransaction(row());
      await dao.softDelete('tx-1', now: t1);

      expect(await dao.softDelete('tx-1', now: t1 + 1), 0);
      expect(await dao.softDelete('tx-missing', now: t1), 0);
      expect((await dao.findById('tx-1'))!.deletedAt, t1);
    });
  });

  group('query plan, on the SQL the DAO really sends', () {
    // `selectTransactions` is the statement `watchTransactions` watches, so these plans cannot drift from the query.
    Future<String> planOf(SimpleSelectStatement<$TransactionsTableTable, TransactionRow> statement) async {
      final query = statement.constructQuery();
      final rows = await db.customSelect('EXPLAIN QUERY PLAN ${query.sql}', variables: query.introducedVariables).get();

      return rows.map((r) => r.read<String>('detail')).join('\n');
    }

    test('the unfiltered list reads the owner index in order, with no sort', () async {
      final plan = await planOf(dao.selectTransactions(localOwnerId, limit: 50));

      expect(plan, contains('SEARCH transactions USING INDEX transactions_owner_id_occurred_at_id'));
      expect(plan, isNot(contains('TEMP B-TREE')));
    });

    test('a date range seeks into the owner index rather than filtering after it', () async {
      final plan = await planOf(dao.selectTransactions(localOwnerId, limit: 50, fromMillis: 200, toMillis: 300));

      expect(plan, contains('transactions_owner_id_occurred_at_id (owner_id=? AND occurred_at>? AND occurred_at<?)'));
      expect(plan, isNot(contains('TEMP B-TREE')));
    });

    test('the account filter never scans the table — the two plans SQLite may pick are pinned until W8', () async {
      // SQLite's pick for an OR across two columns differs between versions: the owner index plus a filter, or `MULTI-INDEX OR` plus a sort. Never a `SCAN`.
      final plan = await planOf(dao.selectTransactions(localOwnerId, limit: 50, accountIds: {'acc-cash'}));

      expect(plan, isNot(contains('SCAN transactions')));
      expect(plan, anyOf(contains('USING INDEX transactions_owner_id_occurred_at_id'), contains('MULTI-INDEX OR')));
    });

    test('the delete check seeks both account indexes and never walks the owner one', () async {
      // `+owner_id` takes the owner term out of the index choice; without it, SQLite read every row the owner has for an account with none.
      final rows = await db
          .customSelect(
            'EXPLAIN QUERY PLAN ${TransactionDao.hasLiveTransactionsSql}',
            variables: [Variable.withString(localOwnerId), Variable.withString('acc-cash')],
          )
          .get();
      final plan = rows.map((r) => r.read<String>('detail')).join('\n');

      expect(plan, contains('MULTI-INDEX OR'));
      expect(plan, contains('transactions_account_id_occurred_at_id (account_id=?)'));
      expect(plan, contains('transactions_destination_account_id_occurred_at_id (destination_account_id=?)'));
      expect(plan, isNot(contains('transactions_owner_id_occurred_at_id')));
      expect(plan, isNot(contains('SCAN transactions')));
    });
  });
}
