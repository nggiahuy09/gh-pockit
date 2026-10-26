import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/features/accounts/data/daos/account_dao.dart';

const _t0 = 1757800000000;
const _t1 = 1757800060000;
const _otherOwner = 'someone-else';

AccountsTableCompanion _row({String id = 'a1', String name = 'Ví tiền mặt', String ownerId = localOwnerId, int at = _t0, bool isArchived = false}) => AccountsTableCompanion.insert(
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

/// Not [AccountDao.softDelete], which is under test; not `customStatement`, which does not tell drift the table changed, so no `watch()` would re-emit.
Future<void> _softDelete(GPAppDatabase db, String id) =>
    (db.update(db.accountsTable)..where((t) => t.id.equals(id))).write(const AccountsTableCompanion(updatedAt: Value(_t1), deletedAt: Value(_t1)));

void main() {
  late GPAppDatabase db;
  late AccountDao dao;

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    dao = AccountDao(db);
  });

  tearDown(() => db.close());

  group('watchAccounts', () {
    test('create → watchAccounts emits the new account', () async {
      final emissions = <List<String>>[];
      final subscription = dao.watchAccounts(localOwnerId).listen((rows) => emissions.add(rows.map((r) => r.name).toList()));

      await pumpEventQueue();
      await dao.insertAccount(_row());
      await pumpEventQueue();

      await subscription.cancel();

      expect(emissions, [
        <String>[],
        ['Ví tiền mặt'],
      ]);
    });

    test('is scoped to one owner', () async {
      await dao.insertAccount(_row(id: 'mine'));
      await dao.insertAccount(_row(id: 'theirs', ownerId: _otherOwner));

      expect((await dao.watchAccounts(localOwnerId).first).map((r) => r.id), ['mine']);
      expect((await dao.watchAccounts(_otherOwner).first).map((r) => r.id), ['theirs']);
    });

    test('hides archived accounts by default and shows them on request', () async {
      await dao.insertAccount(_row(id: 'cash'));
      await dao.insertAccount(_row(id: 'oldCard', name: 'Thẻ cũ'));
      await dao.archive('oldCard', now: _t1);

      expect((await dao.watchAccounts(localOwnerId).first).map((r) => r.id), ['cash']);
      expect((await dao.watchAccounts(localOwnerId, includeArchived: true).first).map((r) => r.id), ['cash', 'oldCard']);
    });

    test('never returns a soft-deleted row, archived or not', () async {
      await dao.insertAccount(_row(id: 'live'));
      await dao.insertAccount(_row(id: 'archived'));
      await dao.archive('archived', now: _t1);
      await _softDelete(db, 'live');
      await _softDelete(db, 'archived');

      expect(await dao.watchAccounts(localOwnerId).first, isEmpty);
      expect(await dao.watchAccounts(localOwnerId, includeArchived: true).first, isEmpty);
      expect(await db.select(db.accountsTable).get(), hasLength(2));
    });

    test('orders by creation, oldest first', () async {
      await dao.insertAccount(_row(id: 'b', name: 'Ăn uống'));
      await dao.insertAccount(_row(id: 'a', name: 'Ví', at: _t1));

      // Id order, or name order under SQLite's BINARY collation, would both give ['a', 'b'].
      expect((await dao.watchAccounts(localOwnerId).first).map((r) => r.id), ['b', 'a']);
    });
  });

  group('findById', () {
    test('finds a tombstone, unlike every other read', () async {
      await dao.insertAccount(_row());
      await _softDelete(db, 'a1');

      final found = await dao.findById('a1');

      expect(found!.deletedAt, _t1);
      expect(await dao.findById('nope'), isNull);
    });
  });

  group('updateAccount', () {
    test('writes the patch and stamps updated_at from the caller instant', () async {
      await dao.insertAccount(_row());

      final written = await dao.updateAccount(
        'a1',
        patch: const AccountsTableCompanion(name: Value('Tiền mặt')),
        baseVersion: 1,
        now: _t1,
      );

      expect(written, 1);
      final updated = await dao.findById('a1');
      expect(updated!.name, 'Tiền mặt');
      expect(updated.initialBalance, 1500000);
      expect(updated.createdAt, _t0);
      expect(updated.updatedAt, _t1);
    });

    test('does not touch version', () async {
      await dao.insertAccount(_row());

      await dao.updateAccount(
        'a1',
        patch: const AccountsTableCompanion(name: Value('Tiền mặt')),
        baseVersion: 1,
        now: _t1,
      );

      // Regression guard: a local bump would send a base version the server never issued, and every edit would conflict (§7).
      expect((await dao.findById('a1'))!.version, 1);
    });

    test('writes nothing when the base version is stale', () async {
      await dao.insertAccount(_row());

      final written = await dao.updateAccount(
        'a1',
        patch: const AccountsTableCompanion(name: Value('Tiền mặt')),
        baseVersion: 7,
        now: _t1,
      );

      expect(written, 0);
      expect((await dao.findById('a1'))!.name, 'Ví tiền mặt');
    });

    test('refuses a soft-deleted row', () async {
      await dao.insertAccount(_row());
      await _softDelete(db, 'a1');

      expect(
        await dao.updateAccount(
          'a1',
          patch: const AccountsTableCompanion(name: Value('x')),
          baseVersion: 1,
          now: _t1,
        ),
        0,
      );
      expect((await dao.findById('a1'))!.name, 'Ví tiền mặt');
    });
  });

  group('archive', () {
    test('hides the account without deleting it, and unarchive brings it back', () async {
      await dao.insertAccount(_row());

      expect(await dao.archive('a1', now: _t1), 1);

      final archived = await dao.findById('a1');
      expect(archived!.isArchived, true);
      expect(archived.deletedAt, isNull);
      expect(archived.updatedAt, _t1);
      expect(archived.version, 1);
      expect(await dao.watchAccounts(localOwnerId).first, isEmpty);

      expect(await dao.unarchive('a1', now: _t1), 1);

      expect((await dao.watchAccounts(localOwnerId).first).single.id, 'a1');
    });

    test('writes nothing for an unknown id or a soft-deleted row', () async {
      await dao.insertAccount(_row());
      await _softDelete(db, 'a1');

      expect(await dao.archive('nope', now: _t1), 0);
      expect(await dao.archive('a1', now: _t1), 0);
    });
  });

  group('watchAccount', () {
    test('emits the row, then null once it is gone', () async {
      await dao.insertAccount(_row());

      final emissions = <AccountRow?>[];
      final subscription = dao.watchAccount(id: 'a1', ownerId: localOwnerId).listen(emissions.add);
      await pumpEventQueue();

      await _softDelete(db, 'a1');
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions.first!.id, 'a1');
      expect(emissions.last, isNull);
    });

    test('emits null for an unknown id', () async {
      expect(await dao.watchAccount(id: 'nope', ownerId: localOwnerId).first, isNull);
    });

    test('hides an archived row, with no opt-in', () async {
      await dao.insertAccount(_row(isArchived: true));

      expect(await dao.watchAccount(id: 'a1', ownerId: localOwnerId).first, isNull);
    });

    test('never reaches across owners', () async {
      await dao.insertAccount(_row(ownerId: _otherOwner));

      expect(await dao.watchAccount(id: 'a1', ownerId: localOwnerId).first, isNull);
    });
  });

  group('softDelete', () {
    test('stamps the tombstone and moves updated_at, leaving version alone', () async {
      await dao.insertAccount(_row());

      expect(await dao.softDelete('a1', now: _t1), 1);

      final deleted = await dao.findById('a1');
      expect(deleted, isNotNull);
      expect(deleted!.deletedAt, _t1);
      expect(deleted.updatedAt, _t1);
      expect(deleted.version, 1);
    });

    test('removes the row from every user-facing read', () async {
      await dao.insertAccount(_row());
      await dao.softDelete('a1', now: _t1);

      expect(await dao.watchAccounts(localOwnerId).first, isEmpty);
      expect(await dao.watchAccounts(localOwnerId, includeArchived: true).first, isEmpty);
      expect(await dao.watchAccount(id: 'a1', ownerId: localOwnerId).first, isNull);
      expect(await dao.findById('a1'), isNotNull);
    });

    test('writes nothing the second time, or for an unknown id', () async {
      await dao.insertAccount(_row());

      expect(await dao.softDelete('a1', now: _t1), 1);
      expect(await dao.softDelete('a1', now: _t1), 0);
      expect(await dao.softDelete('nope', now: _t1), 0);
    });

    test('deletes an archived account without un-archiving it', () async {
      await dao.insertAccount(_row(isArchived: true));

      expect(await dao.softDelete('a1', now: _t1), 1);
      expect((await dao.findById('a1'))!.isArchived, true);
    });
  });
}
