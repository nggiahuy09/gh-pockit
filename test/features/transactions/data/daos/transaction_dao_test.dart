// `isNull`/`isNotNull` are both drift SQL predicates and matchers; this file wants the matchers. The SQL side stays reachable as `.isNull()` on a column.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';

/// `TransactionDao` (W4 T5), on an in-memory database with real SQL — the same stance as `account_dao_test.dart`.
///
/// What is covered is the DAO's own policy: which rows a read may see and in what order, what each filter means, which columns a write stamps and which
/// it leaves alone, and — because this is the table fifty thousand rows land in — which plan SQLite picks for the queries the list really sends. The
/// constraints themselves are `transactions_table_test.dart`'s.
///
/// Instants are small literals rather than a `FakeClock`: the DAO holds no clock by design, so `now` is just an argument.
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

  /// Stands in for `TransactionMapper` until T6 builds it. `syncStatus` defaults to `'synced'` on purpose: every write test below then proves the DAO
  /// stamps `'pending'` over whatever the companion carried.
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

  /// Soft-deletes through drift's update builder rather than [TransactionDao.softDelete] — the reason `account_dao_test.dart` gives: the groups that
  /// assert some *other* method ignores a tombstone must not share a setup with the method under test.
  Future<void> tombstone(String id) =>
      (db.update(db.transactionsTable)..where((t) => t.id.equals(id))).write(const TransactionsTableCompanion(deletedAt: Value(t1), updatedAt: Value(t1)));

  /// The ids of the first emission of [watchTransactions] with these filters.
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

      // `pumpEventQueue`, never `Future.delayed` (§8): it only yields so the stream can deliver what is already queued.
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
      // Rows entered with a date and no time share `occurred_at`. Without `id DESC` their order is whatever SQLite returns, and it may change between two
      // emissions of the same list (ADR-0011).
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
      // Matching only `account_id` would give the cash account a history with every transfer into it missing (ADR-0011).
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
      // So one month's `to` can be the next month's `from` without a transaction at exactly midnight landing in both.
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
      // `IN ()` is false. The domain never sends an empty set (`TransactionQuery` turns one into no filter), so the DAO does not guess on its behalf.
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
    // The row `updateTransaction` needs in order to tell a conflict from a deletion, and the one W14's applier reconciles the server's copy against.
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
      // An old transaction on an archived account must stay editable (ADR-0010).
      expect(await dao.liveAccountCurrency(localOwnerId, 'acc-archived'), 'VND');
    });

    test('answers null for a deleted account, an unknown one, or one of another owner', () async {
      await (db.update(db.accountsTable)..where((t) => t.id.equals('acc-bank'))).write(const AccountsTableCompanion(deletedAt: Value(t1)));

      expect(await dao.liveAccountCurrency(localOwnerId, 'acc-bank'), isNull);
      expect(await dao.liveAccountCurrency(localOwnerId, 'acc-missing'), isNull);
      // A foreign key would accept `acc-theirs` — the row exists. The rule is that the account is the owner's (ADR-0010).
      expect(await dao.liveAccountCurrency(localOwnerId, 'acc-theirs'), isNull);
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
      // A row the server had is `pending` again the moment it is edited locally.
      expect(stored.syncStatus, 'pending');
      // The server's number (§7): bumping it here would send a base version the server never issued.
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
      // Editing a tombstone would move its `updated_at` and push a resurrected row at the next sync.
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
      // Still on disk (golden rule 5), and moved on `updated_at` so W14's pull sees the deletion.
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
      // The first deletion's instant is the one kept.
      expect((await dao.findById('tx-1'))!.deletedAt, t1);
    });
  });

  group('query plan, on the SQL the DAO really sends', () {
    // `selectTransactions` is the statement `watchTransactions` watches, so these plans cannot drift from the query. `SEARCH` is an index seek; `SCAN` is
    // a full pass over a table or an index, which is what fifty thousand rows cannot afford on every emission.
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
      // An `OR` across two columns cannot be served in order by one index. SQLite picks by cost, and the pick differs between versions: walk the owner
      // index newest-first and filter (no sort, but a rarely used account reads far back), or merge the two account indexes and sort what matched
      // (`MULTI-INDEX OR` + `TEMP B-TREE`). Both are known and both wait for W8's numbers; the `UNION ALL` fix is written up on
      // `TransactionDao.watchTransactions`. What must never happen is a `SCAN`.
      final plan = await planOf(dao.selectTransactions(localOwnerId, limit: 50, accountIds: {'acc-cash'}));

      expect(plan, isNot(contains('SCAN transactions')));
      expect(plan, anyOf(contains('USING INDEX transactions_owner_id_occurred_at_id'), contains('MULTI-INDEX OR')));
    });
  });
}
