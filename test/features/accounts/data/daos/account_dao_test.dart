import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/features/accounts/data/daos/account_dao.dart';

void main() {
  const t0 = 1757800000000;
  const t1 = 1757800060000;
  const otherOwner = 'someone-else';

  late GPAppDatabase db;
  late AccountDao dao;

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    dao = AccountDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  AccountsTableCompanion row({
    String id = 'a1',
    String ownerId = localOwnerId,
    String name = 'Ví tiền mặt',
    bool isArchived = false,
    int at = t0,
  }) => AccountsTableCompanion.insert(
    id: id,
    ownerId: ownerId,
    name: name,
    type: 'cash',
    currencyCode: 'VND',
    initialBalance: 1500000,
    isArchived: isArchived,
    createdAt: at,
    updatedAt: at,
    version: 1,
  );

  /// Not [AccountDao.softDelete], which is itself under test; not `customStatement`, which does not tell drift the table changed, so no `watch()` would re-emit.
  Future<void> softDelete(String id) => (db.update(db.accountsTable)..where((t) => t.id.equals(id))).write(
    const AccountsTableCompanion(deletedAt: Value(t1), updatedAt: Value(t1)),
  );

  group('watchAccounts', () {
    test('create → watchAccounts emits the new account', () async {
      final emissions = <List<String>>[];
      final subscription = dao.watchAccounts(localOwnerId).listen((rows) => emissions.add(rows.map((r) => r.name).toList()));

      // Yields to the event loop so the stream can deliver what is already queued.
      await pumpEventQueue();
      await dao.insertAccount(row());
      await pumpEventQueue();

      await subscription.cancel();

      expect(emissions, [
        <String>[],
        ['Ví tiền mặt'],
      ]);
    });

    test('is scoped to one owner', () async {
      await dao.insertAccount(row(id: 'mine'));
      await dao.insertAccount(row(id: 'theirs', ownerId: otherOwner));

      expect((await dao.watchAccounts(localOwnerId).first).map((r) => r.id), ['mine']);
      expect((await dao.watchAccounts(otherOwner).first).map((r) => r.id), ['theirs']);
    });

    test('hides archived accounts by default and shows them on request', () async {
      await dao.insertAccount(row(id: 'cash'));
      await dao.insertAccount(row(id: 'oldCard', name: 'Thẻ cũ'));
      await dao.archive('oldCard', now: t1);

      expect((await dao.watchAccounts(localOwnerId).first).map((r) => r.id), ['cash']);
      expect((await dao.watchAccounts(localOwnerId, includeArchived: true).first).map((r) => r.id), ['cash', 'oldCard']);
    });

    test('never returns a soft-deleted row, archived or not', () async {
      await dao.insertAccount(row(id: 'live'));
      await dao.insertAccount(row(id: 'archived'));
      await dao.archive('archived', now: t1);
      await softDelete('live');
      await softDelete('archived');

      expect(await dao.watchAccounts(localOwnerId).first, isEmpty);
      expect(await dao.watchAccounts(localOwnerId, includeArchived: true).first, isEmpty);
      expect(await db.select(db.accountsTable).get(), hasLength(2));
    });

    test('orders by creation, oldest first', () async {
      await dao.insertAccount(row(id: 'b', name: 'Ăn uống'));
      await dao.insertAccount(row(id: 'a', name: 'Ví', at: t1));

      // Id order, or name order under SQLite's BINARY collation ("Ví" < "Ăn uống"), would both give ['a', 'b'].
      expect((await dao.watchAccounts(localOwnerId).first).map((r) => r.id), ['b', 'a']);
    });
  });

  group('findById', () {
    test('finds a tombstone, unlike every other read', () async {
      await dao.insertAccount(row());
      await softDelete('a1');

      final found = await dao.findById('a1');

      expect(found!.deletedAt, t1);
      expect(await dao.findById('nope'), isNull);
    });
  });

  group('updateAccount', () {
    test('writes the patch and stamps updated_at from the caller instant', () async {
      await dao.insertAccount(row());

      final written = await dao.updateAccount(
        'a1',
        baseVersion: 1,
        patch: const AccountsTableCompanion(name: Value('Tiền mặt')),
        now: t1,
      );

      expect(written, 1);
      final updated = await dao.findById('a1');
      expect(updated!.name, 'Tiền mặt');
      expect(updated.initialBalance, 1500000);
      expect(updated.createdAt, t0);
      expect(updated.updatedAt, t1);
    });

    test('does not touch version', () async {
      await dao.insertAccount(row());

      await dao.updateAccount(
        'a1',
        baseVersion: 1,
        patch: const AccountsTableCompanion(name: Value('Tiền mặt')),
        now: t1,
      );

      // The server's to move (§7): a local bump would send a base version it never issued, and every edit would conflict.
      expect((await dao.findById('a1'))!.version, 1);
    });

    test('writes nothing when the base version is stale', () async {
      await dao.insertAccount(row());

      final written = await dao.updateAccount(
        'a1',
        baseVersion: 7,
        patch: const AccountsTableCompanion(name: Value('Tiền mặt')),
        now: t1,
      );

      expect(written, 0);
      expect((await dao.findById('a1'))!.name, 'Ví tiền mặt');
    });

    test('refuses a soft-deleted row', () async {
      await dao.insertAccount(row());
      await softDelete('a1');

      expect(
        await dao.updateAccount(
          'a1',
          baseVersion: 1,
          patch: const AccountsTableCompanion(name: Value('x')),
          now: t1,
        ),
        0,
      );
      expect((await dao.findById('a1'))!.name, 'Ví tiền mặt');
    });
  });

  group('archive', () {
    test('hides the account without deleting it, and unarchive brings it back', () async {
      await dao.insertAccount(row());

      expect(await dao.archive('a1', now: t1), 1);

      final archived = await dao.findById('a1');
      expect(archived!.isArchived, true);
      expect(archived.deletedAt, isNull);
      expect(archived.updatedAt, t1);
      expect(archived.version, 1);
      expect(await dao.watchAccounts(localOwnerId).first, isEmpty);

      expect(await dao.unarchive('a1', now: t1), 1);

      expect((await dao.watchAccounts(localOwnerId).first).single.id, 'a1');
    });

    test('writes nothing for an unknown id or a soft-deleted row', () async {
      await dao.insertAccount(row());
      await softDelete('a1');

      expect(await dao.archive('nope', now: t1), 0);
      expect(await dao.archive('a1', now: t1), 0);
    });
  });

  group('watchAccount', () {
    test('emits the row, then null once it is gone', () async {
      await dao.insertAccount(row());

      final emissions = <AccountRow?>[];
      final subscription = dao.watchAccount(localOwnerId, 'a1').listen(emissions.add);
      await pumpEventQueue();

      await softDelete('a1');
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions.first!.id, 'a1');
      expect(emissions.last, isNull);
    });

    test('emits null for an unknown id', () async {
      expect(await dao.watchAccount(localOwnerId, 'nope').first, isNull);
    });

    test('hides an archived row, with no opt-in', () async {
      await dao.insertAccount(row(isArchived: true));

      expect(await dao.watchAccount(localOwnerId, 'a1').first, isNull);
    });

    test('never reaches across owners', () async {
      await dao.insertAccount(row(ownerId: otherOwner));

      expect(await dao.watchAccount(localOwnerId, 'a1').first, isNull);
    });
  });

  group('softDelete', () {
    test('stamps the tombstone and moves updated_at, leaving version alone', () async {
      await dao.insertAccount(row());

      expect(await dao.softDelete('a1', now: t1), 1);

      final deleted = await dao.findById('a1');
      expect(deleted, isNotNull);
      expect(deleted!.deletedAt, t1);
      expect(deleted.updatedAt, t1);
      expect(deleted.version, 1);
    });

    test('removes the row from every user-facing read', () async {
      await dao.insertAccount(row());
      await dao.softDelete('a1', now: t1);

      expect(await dao.watchAccounts(localOwnerId).first, isEmpty);
      expect(await dao.watchAccounts(localOwnerId, includeArchived: true).first, isEmpty);
      expect(await dao.watchAccount(localOwnerId, 'a1').first, isNull);
      // The one read that still sees it: sync has to find the rows it deleted.
      expect(await dao.findById('a1'), isNotNull);
    });

    test('writes nothing the second time, or for an unknown id', () async {
      await dao.insertAccount(row());

      expect(await dao.softDelete('a1', now: t1), 1);
      expect(await dao.softDelete('a1', now: t1), 0);
      expect(await dao.softDelete('nope', now: t1), 0);
    });

    test('deletes an archived account without un-archiving it', () async {
      await dao.insertAccount(row(isArchived: true));

      expect(await dao.softDelete('a1', now: t1), 1);
      expect((await dao.findById('a1'))!.isArchived, true);
    });
  });
}
