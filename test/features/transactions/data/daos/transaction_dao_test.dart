import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';

const _t0 = 1000;
const _t1 = 2000;
const _otherOwner = 'someone-else';

void main() {
  late GPAppDatabase db;
  late TransactionDao dao;

  setUp(() async {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    dao = TransactionDao(db);

    await _insertAccount(db, 'acc-cash');
    await _insertAccount(db, 'acc-bank');
    await _insertAccount(db, 'acc-usd', currencyCode: 'USD');
    await _insertAccount(db, 'acc-archived', isArchived: true);
    await _insertAccount(db, 'acc-theirs', ownerId: _otherOwner);

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
              createdAt: _t0,
              updatedAt: _t0,
              version: 1,
            ),
          );
    }
  });

  tearDown(() => db.close());

  group('watchTransactions', () {
    test('emits a transaction written after it subscribed, with no refresh', () async {
      final emissions = <List<String>>[];
      final subscription = dao.watchTransactions(localOwnerId, limit: 50).listen((rows) => emissions.add(rows.map((r) => r.id).toList()));

      // Yields to the event loop so the stream can deliver what is already queued.
      await pumpEventQueue();
      await dao.insertTransaction(_row());
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions, [
        <String>[],
        ['tx-1'],
      ]);
    });

    test('re-emits on an update and on a soft delete', () async {
      await dao.insertTransaction(_row());

      final emissions = <List<int>>[];
      final subscription = dao.watchTransactions(localOwnerId, limit: 50).listen((rows) => emissions.add(rows.map((r) => r.amountMinor).toList()));

      await pumpEventQueue();
      await dao.updateTransaction(
        'tx-1',
        patch: const TransactionsTableCompanion(amountMinor: Value(95000)),
        baseVersion: 1,
        now: _t1,
      );
      await pumpEventQueue();
      await dao.softDelete('tx-1', now: _t1);
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions, [
        [125000],
        [95000],
        <int>[],
      ]);
    });

    test('is scoped to one owner', () async {
      await dao.insertTransaction(_row());
      await dao.insertTransaction(_row(accountId: 'acc-theirs', categoryId: null, id: 'tx-theirs', ownerId: _otherOwner));

      expect(await _idsOf(dao), ['tx-1']);
    });

    test('never returns a soft-deleted row', () async {
      await dao.insertTransaction(_row());
      await dao.insertTransaction(_row(id: 'tx-2'));
      await _tombstone(db, 'tx-1');

      expect(await _idsOf(dao), ['tx-2']);
    });

    test('orders newest first, and by id — descending — among rows that share an instant', () async {
      // Inserted out of id order, so insertion (rowid) order would not pass.
      await dao.insertTransaction(_row(id: 'tx-a'));
      await dao.insertTransaction(_row(id: 'tx-c'));
      await dao.insertTransaction(_row(id: 'tx-b'));
      await dao.insertTransaction(_row(id: 'tx-new', occurredAt: _t1));

      expect(await _idsOf(dao), ['tx-new', 'tx-c', 'tx-b', 'tx-a']);
    });

    test('returns at most limit rows — the newest ones', () async {
      for (var i = 1; i <= 5; i++) {
        await dao.insertTransaction(_row(id: 'tx-$i', occurredAt: _t0 + i));
      }

      expect(await _idsOf(dao, limit: 3), ['tx-5', 'tx-4', 'tx-3']);
    });

    test('matches an account on either side of a transfer', () async {
      await dao.insertTransaction(_row(id: 'tx-spent-cash', occurredAt: _t0 + 3));
      await dao.insertTransaction(_transfer(from: 'acc-bank', id: 'tx-bank-to-cash', to: 'acc-cash', occurredAt: _t0 + 2));
      await dao.insertTransaction(_row(accountId: 'acc-bank', id: 'tx-spent-bank', occurredAt: _t0 + 1));

      expect(await _idsOf(dao, accountIds: {'acc-cash'}), ['tx-spent-cash', 'tx-bank-to-cash']);
      expect(await _idsOf(dao, accountIds: {'acc-bank'}), ['tx-bank-to-cash', 'tx-spent-bank']);
    });

    test('filters by category, leaving uncategorised rows out', () async {
      await dao.insertTransaction(_row(id: 'tx-food'));
      await dao.insertTransaction(_row(categoryId: 'cat-rent', id: 'tx-rent'));
      await dao.insertTransaction(_row(categoryId: null, id: 'tx-none'));

      expect(await _idsOf(dao, categoryIds: {'cat-food'}), ['tx-food']);
    });

    test('filters by type', () async {
      await dao.insertTransaction(_row(id: 'tx-expense', occurredAt: _t0 + 3));
      await dao.insertTransaction(_row(id: 'tx-income', type: 'income', occurredAt: _t0 + 2));
      await dao.insertTransaction(_transfer(from: 'acc-cash', id: 'tx-transfer', to: 'acc-bank', occurredAt: _t0 + 1));

      expect(await _idsOf(dao, types: {'expense', 'income'}), ['tx-expense', 'tx-income']);
      expect(await _idsOf(dao, types: {'transfer'}), ['tx-transfer']);
    });

    test('reads the range as [from, to) — from inclusive, to exclusive', () async {
      await dao.insertTransaction(_row(id: 'tx-before', occurredAt: 100));
      await dao.insertTransaction(_row(id: 'tx-at-from', occurredAt: 200));
      await dao.insertTransaction(_row(id: 'tx-inside', occurredAt: 250));
      await dao.insertTransaction(_row(id: 'tx-at-to', occurredAt: 300));

      expect(await _idsOf(dao, fromMillis: 200, toMillis: 300), ['tx-inside', 'tx-at-from']);
      expect(await _idsOf(dao, fromMillis: 300), ['tx-at-to']);
      expect(await _idsOf(dao, toMillis: 200), ['tx-before']);
    });

    test('ANDs every filter together', () async {
      await dao.insertTransaction(_row(id: 'tx-match', occurredAt: 250));
      await dao.insertTransaction(_row(categoryId: 'cat-rent', id: 'tx-other-category', occurredAt: 250));
      await dao.insertTransaction(_row(accountId: 'acc-bank', id: 'tx-other-account', occurredAt: 250));
      await dao.insertTransaction(_row(id: 'tx-out-of-range', occurredAt: 500));

      expect(await _idsOf(dao, accountIds: {'acc-cash'}, categoryIds: {'cat-food'}, types: {'expense'}, fromMillis: 200, toMillis: 300), ['tx-match']);
    });

    test('reads an empty set as SQL does — it matches nothing', () async {
      // The domain never sends one: `TransactionQuery` turns an empty set into no filter.
      await dao.insertTransaction(_row());

      expect(await _idsOf(dao, accountIds: <String>{}), isEmpty);
      expect(await _idsOf(dao), ['tx-1']);
    });
  });

  group('watchTransaction', () {
    test('emits the row, then null once it is soft-deleted', () async {
      await dao.insertTransaction(_row());

      final emissions = <String?>[];
      final subscription = dao.watchTransaction(id: 'tx-1', ownerId: localOwnerId).listen((r) => emissions.add(r?.id));

      await pumpEventQueue();
      await _tombstone(db, 'tx-1');
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions, ['tx-1', null]);
    });

    test('emits null for an unknown id and never reaches across owners', () async {
      await dao.insertTransaction(_row(accountId: 'acc-theirs', categoryId: null, id: 'tx-theirs', ownerId: _otherOwner));

      expect(await dao.watchTransaction(id: 'tx-missing', ownerId: localOwnerId).first, isNull);
      expect(await dao.watchTransaction(id: 'tx-theirs', ownerId: localOwnerId).first, isNull);
    });
  });

  test('findById finds a tombstone, unlike every other read', () async {
    await dao.insertTransaction(_row());
    await _tombstone(db, 'tx-1');

    final found = await dao.findById('tx-1');

    expect(found, isNotNull);
    expect(found?.deletedAt, _t1);
  });

  group('liveAccountCurrency', () {
    test("answers with the account's currency while it is live — archived included", () async {
      expect(await dao.liveAccountCurrency(accountId: 'acc-cash', ownerId: localOwnerId), 'VND');
      expect(await dao.liveAccountCurrency(accountId: 'acc-usd', ownerId: localOwnerId), 'USD');
      expect(await dao.liveAccountCurrency(accountId: 'acc-archived', ownerId: localOwnerId), 'VND');
    });

    test('answers null for a deleted account, an unknown one, or one of another owner', () async {
      await (db.update(db.accountsTable)..where((t) => t.id.equals('acc-bank'))).write(const AccountsTableCompanion(deletedAt: Value(_t1)));

      expect(await dao.liveAccountCurrency(accountId: 'acc-bank', ownerId: localOwnerId), isNull);
      expect(await dao.liveAccountCurrency(accountId: 'acc-missing', ownerId: localOwnerId), isNull);
      expect(await dao.liveAccountCurrency(accountId: 'acc-theirs', ownerId: localOwnerId), isNull);
    });
  });

  group('watchAccountBalances', () {
    test('the four terms: income adds, an expense and a transfer out subtract, a transfer in adds', () async {
      await dao.insertTransaction(_row(categoryId: null, id: 'tx-in', type: 'income', amountMinor: 100000));
      await dao.insertTransaction(_row(id: 'tx-out', amountMinor: 30000));
      await dao.insertTransaction(_transfer(from: 'acc-cash', id: 'tx-move', to: 'acc-bank').copyWith(amountMinor: const Value(20000)));

      final result = await _balances(dao);

      expect(result['acc-cash'], 100000 - 30000 - 20000);
      expect(result['acc-bank'], 20000, reason: 'the arriving side of the transfer, counted once');
    });

    test('starts from the opening balance', () async {
      await _setAccount(db, const AccountsTableCompanion(initialBalance: Value(500000)), 'acc-cash');
      await dao.insertTransaction(_row());

      expect((await _balances(dao))['acc-cash'], 375000);
    });

    test('a deleted transaction counts on neither side', () async {
      await dao.insertTransaction(_transfer(from: 'acc-cash', id: 'tx-move', to: 'acc-bank'));
      await _tombstone(db, 'tx-move');

      final result = await _balances(dao);
      expect(result['acc-cash'], 0);
      expect(result['acc-bank'], 0);
    });

    test('a deleted account leaves the list, and its transfers still count at the other end (ADR-0010)', () async {
      await dao.insertTransaction(_transfer(from: 'acc-bank', id: 'tx-move', to: 'acc-cash').copyWith(amountMinor: const Value(20000)));
      await _setAccount(db, const AccountsTableCompanion(deletedAt: Value(_t1)), 'acc-bank');

      final result = await _balances(dao);
      expect(result.containsKey('acc-bank'), isFalse);
      expect(result['acc-cash'], 20000);
    });

    test("only the owner's live, unarchived accounts, in creation order", () async {
      await _setAccount(db, const AccountsTableCompanion(createdAt: Value(_t0 - 1)), 'acc-usd');

      final rows = await dao.watchAccountBalances(localOwnerId).first;

      expect(rows.map((r) => r.account.id), <String>['acc-usd', 'acc-bank', 'acc-cash']);
    });

    test('a type outside the three adds nothing: the row is unreadable, not guessed', () async {
      await dao.insertTransaction(_row(categoryId: null, id: 'tx-odd', type: 'refund', amountMinor: 999));

      expect((await _balances(dao))['acc-cash'], 0);
    });

    test('re-emits when a transaction is written', () async {
      final emitted = <int>[];
      final subscription = dao.watchAccountBalances(localOwnerId).listen((rows) => emitted.add(rows.firstWhere((r) => r.account.id == 'acc-cash').balanceMinor));
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await dao.insertTransaction(_row(amountMinor: 45000));
      await pumpEventQueue();

      expect(emitted, <int>[0, -45000]);
    });

    test('each side reads through its own index, never the whole table', () async {
      final rows = await db.customSelect('EXPLAIN QUERY PLAN ${TransactionDao.accountBalancesSql}', variables: [Variable.withString(localOwnerId)]).get();
      final plan = rows.map((r) => r.read<String>('detail')).join('\n');

      expect(plan, contains('transactions_account_id_occurred_at_id (account_id=?)'));
      expect(plan, contains('transactions_destination_account_id_occurred_at_id (destination_account_id=?)'));
      expect(plan, isNot(contains('SCAN t')));
    });
  });

  group('hasLiveTransactions', () {
    test('is false for an account no transaction touches', () async {
      await dao.insertTransaction(_row(accountId: 'acc-bank'));

      expect(await dao.hasLiveTransactions(accountId: 'acc-cash', ownerId: localOwnerId), isFalse);
    });

    test('is true for the account a transaction is on', () async {
      await dao.insertTransaction(_row());

      expect(await dao.hasLiveTransactions(accountId: 'acc-cash', ownerId: localOwnerId), isTrue);
    });

    test("is true for a transfer's destination — the side a delete would silently strand", () async {
      await dao.insertTransaction(_transfer(from: 'acc-cash', id: 'tx-1', to: 'acc-bank'));

      expect(await dao.hasLiveTransactions(accountId: 'acc-bank', ownerId: localOwnerId), isTrue);
    });

    test('is true for an archived account — archiving keeps the history', () async {
      await dao.insertTransaction(_row(accountId: 'acc-archived'));

      expect(await dao.hasLiveTransactions(accountId: 'acc-archived', ownerId: localOwnerId), isTrue);
    });

    test('does not count a tombstone', () async {
      await dao.insertTransaction(_row());
      await _tombstone(db, 'tx-1');

      expect(await dao.hasLiveTransactions(accountId: 'acc-cash', ownerId: localOwnerId), isFalse);
    });

    test("does not count another owner's transaction — the `+` keeps the owner out of the index choice, not out of the WHERE", () async {
      await dao.insertTransaction(_row(accountId: 'acc-theirs', categoryId: null, ownerId: _otherOwner));

      expect(await dao.hasLiveTransactions(accountId: 'acc-theirs', ownerId: localOwnerId), isFalse);
      expect(await dao.hasLiveTransactions(accountId: 'acc-theirs', ownerId: _otherOwner), isTrue);
    });
  });

  group('insertTransaction', () {
    test("stamps sync_status 'pending', whatever the companion carried", () async {
      await dao.insertTransaction(_row());

      final stored = await db.select(db.transactionsTable).getSingle();

      expect(stored.syncStatus, TransactionDao.pendingSyncStatus);
      expect(stored.syncStatus, 'pending');
    });
  });

  group('updateTransaction', () {
    test("writes the patch, stamps updated_at and 'pending', and leaves version alone", () async {
      await dao.insertTransaction(_row());
      await db.update(db.transactionsTable).write(const TransactionsTableCompanion(syncStatus: Value('synced')));

      final written = await dao.updateTransaction(
        'tx-1',
        patch: const TransactionsTableCompanion(amountMinor: Value(95000), note: Value('Bún chả')),
        baseVersion: 1,
        now: _t1,
      );
      final stored = await db.select(db.transactionsTable).getSingle();

      expect(written, 1);
      expect(stored.amountMinor, 95000);
      expect(stored.note, 'Bún chả');
      expect(stored.updatedAt, _t1);
      expect(stored.syncStatus, 'pending');
      expect(stored.version, 1);
      expect(stored.createdAt, _t0);
    });

    test('writes nothing when the base version is stale', () async {
      await dao.insertTransaction(_row());

      final written = await dao.updateTransaction(
        'tx-1',
        patch: const TransactionsTableCompanion(amountMinor: Value(95000)),
        baseVersion: 2,
        now: _t1,
      );

      expect(written, 0);
      expect((await db.select(db.transactionsTable).getSingle()).amountMinor, 125000);
    });

    test('refuses a soft-deleted row', () async {
      await dao.insertTransaction(_row());
      await _tombstone(db, 'tx-1');

      final written = await dao.updateTransaction(
        'tx-1',
        patch: const TransactionsTableCompanion(amountMinor: Value(95000)),
        baseVersion: 1,
        now: _t1,
      );

      expect(written, 0);
    });
  });

  group('softDelete', () {
    test("stamps deleted_at, updated_at and 'pending', leaving version alone", () async {
      await dao.insertTransaction(_row());
      await db.update(db.transactionsTable).write(const TransactionsTableCompanion(syncStatus: Value('synced')));

      final written = await dao.softDelete('tx-1', now: _t1);
      final stored = await db.select(db.transactionsTable).getSingle();

      expect(written, 1);
      expect(stored.deletedAt, _t1);
      expect(stored.updatedAt, _t1);
      expect(stored.syncStatus, 'pending');
      expect(stored.version, 1);
    });

    test('writes nothing the second time, or for an unknown id', () async {
      await dao.insertTransaction(_row());
      await dao.softDelete('tx-1', now: _t1);

      expect(await dao.softDelete('tx-1', now: _t1 + 1), 0);
      expect(await dao.softDelete('tx-missing', now: _t1), 0);
      expect((await dao.findById('tx-1'))?.deletedAt, _t1);
    });
  });

  group('restore', () {
    test("clears deleted_at, stamps updated_at and 'pending', leaving version alone", () async {
      await dao.insertTransaction(_row());
      await dao.softDelete('tx-1', now: _t1);
      await db.update(db.transactionsTable).write(const TransactionsTableCompanion(syncStatus: Value('synced')));

      final written = await dao.restore('tx-1', now: _t1 + 1);
      final stored = await db.select(db.transactionsTable).getSingle();

      expect(written, 1);
      expect(stored.deletedAt, isNull);
      expect(stored.updatedAt, _t1 + 1);
      expect(stored.syncStatus, 'pending');
      expect(stored.version, 1);
    });

    test('writes nothing for a live row or an unknown id', () async {
      await dao.insertTransaction(_row());

      expect(await dao.restore('tx-1', now: _t1), 0);
      expect(await dao.restore('tx-missing', now: _t1), 0);
      expect((await dao.findById('tx-1'))?.updatedAt, isNot(_t1));
    });
  });

  group('query plan, on the SQL the DAO really sends', () {
    // `selectTransactions` is the statement `watchTransactions` watches, so these plans cannot drift from the query.
    test('the unfiltered list reads the owner index in order, with no sort', () async {
      final plan = await _planOf(db, dao.selectTransactions(localOwnerId, limit: 50));

      expect(plan, contains('SEARCH transactions USING INDEX transactions_owner_id_occurred_at_id'));
      expect(plan, isNot(contains('TEMP B-TREE')));
    });

    test('a date range seeks into the owner index rather than filtering after it', () async {
      final plan = await _planOf(db, dao.selectTransactions(localOwnerId, fromMillis: 200, limit: 50, toMillis: 300));

      expect(plan, contains('transactions_owner_id_occurred_at_id (owner_id=? AND occurred_at>? AND occurred_at<?)'));
      expect(plan, isNot(contains('TEMP B-TREE')));
    });

    test('the account filter never scans the table, whichever of its two plans SQLite picks', () async {
      // SQLite's pick for an OR across two columns differs between versions: the owner index plus a filter, or `MULTI-INDEX OR` plus a sort. Never a `SCAN`.
      final plan = await _planOf(db, dao.selectTransactions(localOwnerId, accountIds: {'acc-cash'}, limit: 50));

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

Future<void> _insertAccount(GPAppDatabase db, String id, {String currencyCode = 'VND', String ownerId = localOwnerId, bool isArchived = false}) => db
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
        createdAt: _t0,
        updatedAt: _t0,
        version: 1,
      ),
    );

/// `syncStatus` is 'synced' on purpose, so every write test proves the DAO stamps 'pending' over it.
TransactionsTableCompanion _row({
  String accountId = 'acc-cash',
  String? categoryId = 'cat-food',
  String? destinationAccountId,
  String id = 'tx-1',
  String? note,
  String ownerId = localOwnerId,
  String type = 'expense',
  int amountMinor = 125000,
  int occurredAt = _t0,
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
  createdAt: _t0,
  updatedAt: _t0,
  version: 1,
  syncStatus: 'synced',
);

TransactionsTableCompanion _transfer({required String from, required String id, required String to, int occurredAt = _t0}) =>
    _row(accountId: from, categoryId: null, destinationAccountId: to, id: id, type: 'transfer', occurredAt: occurredAt);

/// Not [TransactionDao.softDelete], which is itself under test; not `customStatement`, which does not tell drift the table changed.
Future<void> _tombstone(GPAppDatabase db, String id) =>
    (db.update(db.transactionsTable)..where((t) => t.id.equals(id))).write(const TransactionsTableCompanion(updatedAt: Value(_t1), deletedAt: Value(_t1)));

Future<List<String>> _idsOf(TransactionDao dao, {Set<String>? accountIds, Set<String>? categoryIds, Set<String>? types, int? fromMillis, int limit = 50, int? toMillis}) async {
  final rows = await dao
      .watchTransactions(localOwnerId, accountIds: accountIds, categoryIds: categoryIds, types: types, fromMillis: fromMillis, limit: limit, toMillis: toMillis)
      .first;

  return rows.map((row) => row.id).toList();
}

Future<Map<String, int>> _balances(TransactionDao dao) async => {for (final row in await dao.watchAccountBalances(localOwnerId).first) row.account.id: row.balanceMinor};

Future<void> _setAccount(GPAppDatabase db, AccountsTableCompanion patch, String id) => (db.update(db.accountsTable)..where((a) => a.id.equals(id))).write(patch);

Future<String> _planOf(GPAppDatabase db, SimpleSelectStatement<$TransactionsTableTable, TransactionRow> statement) async {
  final query = statement.constructQuery();
  final rows = await db.customSelect('EXPLAIN QUERY PLAN ${query.sql}', variables: query.introducedVariables).get();

  return rows.map((row) => row.read<String>('detail')).join('\n');
}
