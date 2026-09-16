import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/features/accounts/data/daos/account_dao.dart';

import '../../../../helpers/fake_clock.dart';

/// The first DAO under test (W2 T4), and the file that closes W2: its **done** criterion is `create → watchAccounts emit`, asserted first below.
///
/// What is covered here is policy, not drift. That a write reaches SQLite and that a `watch()` re-emits are already settled in `database_test.dart`, and
/// the `accounts` columns and constraints in `accounts_table_test.dart`. What this file pins down is the set of decisions the DAO makes on every call —
/// which rows a read may see, which columns a write is allowed to move, and which it must leave alone — because each one is invisible until P4, when
/// getting it wrong shows up as a row that never syncs or an edit that reports a phantom conflict.
void main() {
  late GPAppDatabase db;
  late FakeClock clock;
  late AccountDao dao;

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    clock = FakeClock();
    dao = AccountDao(db, clock: clock);
  });

  tearDown(() async {
    await db.close();
  });

  Future<AccountRow> createAccount({
    String id = 'a1',
    String name = 'Ví tiền mặt',
    String type = 'cash',
    String currencyCode = 'VND',
    int initialBalance = 1500000,
  }) => dao.insertAccount(id: id, name: name, type: type, currencyCode: currencyCode, initialBalance: initialBalance);

  /// Soft-deletes through raw SQL rather than through the DAO: the repository owns soft delete at T6, and these tests need a tombstone to exist now in
  /// order to assert that every DAO path already ignores one.
  Future<void> softDelete(String id) => db.customStatement('UPDATE accounts SET deleted_at = ? WHERE id = ?', [clock.nowEpochMillis(), id]);

  group('watchAccounts', () {
    test('create → watchAccounts emits the new account', () async {
      // The W2 done criterion, and the assertion ADR-0001 was waiting on before moving from draft to Accepted: a write with no manual invalidation
      // repaints the list. Golden rule 1 is only livable because of it.
      final emissions = <List<String>>[];
      final subscription = dao.watchAccounts().listen((rows) => emissions.add(rows.map((r) => r.name).toList()));

      // `pumpEventQueue`, never `Future.delayed` (§8) — this only yields to the event loop so a stream can deliver what is already queued.
      await pumpEventQueue();
      await createAccount();
      await pumpEventQueue();

      await subscription.cancel();

      expect(emissions, [
        <String>[],
        ['Ví tiền mặt'],
      ]);
    });

    test('hides archived accounts by default and shows them on request', () async {
      await createAccount(id: 'cash');
      await createAccount(id: 'oldCard', name: 'Thẻ cũ');
      await dao.archive('oldCard');

      // The default exists so archiving actually gets an account out of the way; an archived row that still appeared in the list would make the feature
      // a no-op. The opt-in branch is what the settings screen that un-archives reads.
      expect((await dao.watchAccounts().first).map((r) => r.id), ['cash']);
      expect((await dao.watchAccounts(includeArchived: true).first).map((r) => r.id), ['cash', 'oldCard']);
    });

    test('never returns a soft-deleted row, archived or not', () async {
      await createAccount(id: 'live');
      await createAccount(id: 'archived');
      await dao.archive('archived');
      await softDelete('live');
      await softDelete('archived');

      // Golden rule 5: `deleted_at` is a tombstone the server still has to learn about, so the row stays on disk — and every read filters it out. The
      // archived-inclusive branch is checked too, because that is the query most likely to be written without the filter.
      expect(await dao.watchAccounts().first, isEmpty);
      expect(await dao.watchAccounts(includeArchived: true).first, isEmpty);
      expect(await db.select(db.accountsTable).get(), hasLength(2));
    });

    test('orders by creation, oldest first', () async {
      await createAccount(id: 'b', name: 'Ăn uống');
      clock.advance(const Duration(minutes: 1));
      await createAccount(id: 'a', name: 'Ví');

      // Deliberately not alphabetical: SQLite's BINARY collation would sort "Ăn uống" after "Ví", and the ids here are chosen so a fallback to primary-key
      // order would produce the opposite result and fail this test.
      expect((await dao.watchAccounts().first).map((r) => r.id), ['b', 'a']);
    });
  });

  group('insertAccount', () {
    test('stamps every sync column the table refuses to default', () async {
      final row = await createAccount();

      expect(row.ownerId, localOwnerId);
      // Starts at 1 and is the server's from the first push onwards (§7).
      expect(row.version, 1);
      expect(row.isArchived, false);
      expect(row.deletedAt, isNull);
      // From the injected clock, not `DateTime.now()` — the assertion that makes §8's fake clock load bearing rather than decorative.
      expect(row.createdAt, clock.nowEpochMillis());
      // Equal on a fresh row: one read of the clock feeds both, so the two cannot straddle a millisecond boundary.
      expect(row.updatedAt, row.createdAt);
    });

    test('returns the row as stored, so the caller needs no read-back', () async {
      final returned = await createAccount(initialBalance: -250000);
      final stored = await db.select(db.accountsTable).getSingle();

      // T6 builds its outbox payload from this return value; if it did not match what landed, the mutation would describe a row that does not exist.
      expect(returned, stored);
      expect(returned.initialBalance, -250000);
    });
  });

  group('updateAccount', () {
    test('changes only the named columns and moves updated_at', () async {
      final created = await createAccount();
      clock.advance(const Duration(minutes: 5));

      final updated = await dao.updateAccount('a1', name: 'Tiền mặt');

      expect(updated!.name, 'Tiền mặt');
      // Untouched — a null argument means "leave this alone", which is the whole reason the parameters are optional instead of a companion.
      expect(updated.type, created.type);
      expect(updated.initialBalance, created.initialBalance);
      expect(updated.createdAt, created.createdAt);
      expect(updated.updatedAt, clock.nowEpochMillis());
      expect(updated.updatedAt, greaterThan(created.updatedAt));
    });

    test('does not touch version', () async {
      await createAccount();

      final updated = await dao.updateAccount('a1', name: 'Tiền mặt', initialBalance: 99);

      // The §7 optimistic-concurrency token. The client pushes it as `baseVersion` and the server hands back the next value; a hopeful client-side bump
      // would push a base version the server never issued, so `UPDATE ... WHERE version = ?` would match zero rows and every edit would report a conflict
      // that is not one. This test is the only thing standing between here and that bug, which would not surface until P4.
      expect(updated!.version, 1);
    });

    test('returns null for an unknown id and refuses a soft-deleted row', () async {
      await createAccount();
      await softDelete('a1');

      expect(await dao.updateAccount('nope', name: 'x'), isNull);
      // Editing a tombstone would move its `updated_at` and push a resurrected row at the next sync.
      expect(await dao.updateAccount('a1', name: 'x'), isNull);
      expect((await db.select(db.accountsTable).getSingle()).name, 'Ví tiền mặt');
    });
  });

  group('archive', () {
    test('hides the account without deleting it, and unarchive brings it back', () async {
      final created = await createAccount();
      clock.advance(const Duration(minutes: 5));

      final archived = await dao.archive('a1');

      expect(archived!.isArchived, true);
      // Two states, two columns. An archived account keeps its history and keeps syncing; only `deleted_at` is a tombstone.
      expect(archived.deletedAt, isNull);
      expect(archived.updatedAt, clock.nowEpochMillis());
      // Archiving is an ordinary field change as far as sync is concerned — same reasoning as updateAccount.
      expect(archived.version, created.version);
      expect(await dao.watchAccounts().first, isEmpty);

      final restored = await dao.unarchive('a1');

      // Without a way back, a default that hides archived rows would strand them where nothing can reach them.
      expect(restored!.isArchived, false);
      expect((await dao.watchAccounts().first).single.id, 'a1');
    });

    test('returns null for an unknown id and for a soft-deleted row', () async {
      await createAccount();
      await softDelete('a1');

      expect(await dao.archive('nope'), isNull);
      expect(await dao.archive('a1'), isNull);
    });
  });
}
