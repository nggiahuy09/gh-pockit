// `isNull` is both a drift SQL predicate and a matcher expectation; this file wants the matcher. The SQL side stays reachable as `.isNull()` on a column.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/features/accounts/data/daos/account_dao.dart';

/// The first DAO under test (W2 T4), and the file that closes W2: its **done** criterion is `create → watchAccounts emit`, asserted first below.
///
/// What is covered here is policy, not drift. That a write reaches SQLite and that a `watch()` re-emits are settled in `database_test.dart`, and the
/// `accounts` columns and constraints in `accounts_table_test.dart`. What this file pins down is the set of decisions the DAO makes on every call — which
/// rows a read may see, which columns a write may move, and which it must leave alone — because each one is invisible until P4, when getting it wrong
/// shows up as a row that never syncs, an account visible to the wrong owner, or an edit reporting a conflict that is not one.
///
/// Instants are literals rather than a `FakeClock`: the DAO holds no clock by design (`docs/patterns/local-storage-with-drift.md` §6.2), so `now` is just
/// an argument, and stating it inline is what makes "which instant landed where" readable.
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

  /// Stands in for `AccountMapper` until T6 builds it — the DAO takes a companion the mapper made, never a field list.
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

  /// Soft-deletes through raw SQL: the repository owns soft delete at T6, and these tests need a tombstone now in order to assert that every DAO path
  /// already ignores one.
  Future<void> softDelete(String id) => db.customStatement('UPDATE accounts SET deleted_at = ? WHERE id = ?', [t1, id]);

  group('watchAccounts', () {
    test('create → watchAccounts emits the new account', () async {
      // The W2 done criterion, and the assertion ADR-0001 was waiting on before moving from draft to Accepted: a write with no manual invalidation
      // repaints the list. Golden rule 1 is only livable because of it.
      final emissions = <List<String>>[];
      final subscription = dao.watchAccounts(localOwnerId).listen((rows) => emissions.add(rows.map((r) => r.name).toList()));

      // `pumpEventQueue`, never `Future.delayed` (§8) — this only yields to the event loop so a stream can deliver what is already queued.
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

      // Every row carries `localOwnerId` until W10, so today this filter changes nothing a user could see — which is exactly why it has to be asserted
      // now. Written later, it would mean auditing every query for the one that was never scoped, and the symptom of missing it is one account's rows
      // appearing under another account after a second sign-in on the same device.
      expect((await dao.watchAccounts(localOwnerId).first).map((r) => r.id), ['mine']);
      expect((await dao.watchAccounts(otherOwner).first).map((r) => r.id), ['theirs']);
    });

    test('hides archived accounts by default and shows them on request', () async {
      await dao.insertAccount(row(id: 'cash'));
      await dao.insertAccount(row(id: 'oldCard', name: 'Thẻ cũ'));
      await dao.archive('oldCard', now: t1);

      // The default exists so archiving actually gets an account out of the way; an archived row that still appeared would make the feature a no-op. The
      // opt-in branch is what the screen that un-archives reads.
      expect((await dao.watchAccounts(localOwnerId).first).map((r) => r.id), ['cash']);
      expect((await dao.watchAccounts(localOwnerId, includeArchived: true).first).map((r) => r.id), ['cash', 'oldCard']);
    });

    test('never returns a soft-deleted row, archived or not', () async {
      await dao.insertAccount(row(id: 'live'));
      await dao.insertAccount(row(id: 'archived'));
      await dao.archive('archived', now: t1);
      await softDelete('live');
      await softDelete('archived');

      // Golden rule 5: `deleted_at` is a tombstone the server still has to learn about, so the row stays on disk — and every list read filters it out. The
      // archived-inclusive branch is checked too, because that is the query most likely to be written without the filter.
      expect(await dao.watchAccounts(localOwnerId).first, isEmpty);
      expect(await dao.watchAccounts(localOwnerId, includeArchived: true).first, isEmpty);
      expect(await db.select(db.accountsTable).get(), hasLength(2));
    });

    test('orders by creation, oldest first', () async {
      await dao.insertAccount(row(id: 'b', name: 'Ăn uống'));
      await dao.insertAccount(row(id: 'a', name: 'Ví', at: t1));

      // Deliberately not alphabetical: SQLite's BINARY collation would sort "Ăn uống" after "Ví". The ids are chosen so a fallback to primary-key order
      // would produce the opposite result and fail this test.
      expect((await dao.watchAccounts(localOwnerId).first).map((r) => r.id), ['b', 'a']);
    });
  });

  group('findById', () {
    test('finds a tombstone, unlike every other read', () async {
      await dao.insertAccount(row());
      await softDelete('a1');

      // The one deliberate exception to the `deleted_at IS NULL` filter. `RemoteChangeApplier` at W13 has to find a row it already soft-deleted in order
      // to reconcile it against the server's tombstone; a lookup that hid it would make the applier insert a duplicate.
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
      // Absent in the patch, so untouched — `Value.absent()` leaves a column alone where `Value(null)` would null it.
      expect(updated.initialBalance, 1500000);
      expect(updated.createdAt, t0);
      // Stamped by the DAO, not taken from the patch, so a caller cannot build one that silently skips the pull cursor.
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

      // The §7 optimistic-concurrency token, and the server's to move. A hopeful client-side bump would push a base version the server never issued, so
      // `UPDATE ... WHERE version = ?` would match zero rows and every edit would report a conflict that is not one. Nothing else would fail until P4.
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

      // 0 means the row moved under us. That return value is the local half of the conflict detection in §7, so it has to be a number the caller can act
      // on rather than a silently ignored no-op.
      expect(written, 0);
      expect((await dao.findById('a1'))!.name, 'Ví tiền mặt');
    });

    test('refuses a soft-deleted row', () async {
      await dao.insertAccount(row());
      await softDelete('a1');

      // Editing a tombstone would move its `updated_at` and push a resurrected row at the next sync.
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
      // Two states, two columns. An archived account keeps its history and keeps syncing; only `deleted_at` is a tombstone.
      expect(archived.deletedAt, isNull);
      expect(archived.updatedAt, t1);
      // Archiving is an ordinary field change as far as sync is concerned — same reasoning as updateAccount.
      expect(archived.version, 1);
      expect(await dao.watchAccounts(localOwnerId).first, isEmpty);

      expect(await dao.unarchive('a1', now: t1), 1);

      // Without a way back, a default that hides archived rows would strand them where nothing can reach them.
      expect((await dao.watchAccounts(localOwnerId).first).single.id, 'a1');
    });

    test('writes nothing for an unknown id or a soft-deleted row', () async {
      await dao.insertAccount(row());
      await softDelete('a1');

      expect(await dao.archive('nope', now: t1), 0);
      expect(await dao.archive('a1', now: t1), 0);
    });
  });
}
