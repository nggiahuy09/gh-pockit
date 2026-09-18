// `isNull`/`isNotNull` are both drift SQL predicates and matcher expectations; this file wants the matchers.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/logging/app_logger.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/data/daos/account_dao.dart';
import 'package:ghpockit/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/fake_uuid_generator.dart';
import '../../../../helpers/recording_logger.dart';

/// The first repository under test (W2 T6), on a real in-memory Drift database — the test ADR-0001's flex row promised and T4 could only half-deliver.
///
/// **Not mocked, deliberately.** A repository whose DAO is a mock asserts that the repository calls the methods the test thinks it should, which is a
/// restatement of the implementation. What is worth asserting is what a *user* would notice: that a created account shows up on the stream, that an edit
/// against a stale version is refused rather than silently overwriting, that a deleted account stops appearing. All of those need real SQL.
///
/// The clock and the id generator *are* fakes, because both are sources of nondeterminism this file needs to name: "the row carries the instant the write
/// happened" is only checkable if the test decides what that instant is.
void main() {
  late GPAppDatabase db;
  late AccountDao dao;
  late FakeClock clock;
  late FakeUuidGenerator uuid;
  late RecordingLogger logger;
  late AccountRepositoryImpl repository;

  final startedAt = DateTime.utc(2026, 9, 18, 9);

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    dao = AccountDao(db);
    clock = FakeClock(startedAt);
    uuid = FakeUuidGenerator();
    logger = RecordingLogger(clock: clock);
    repository = AccountRepositoryImpl(dao: dao, clock: clock, uuidGenerator: uuid, logger: logger, ownerId: localOwnerId);
  });

  tearDown(() async {
    await db.close();
  });

  Future<AccountEntity> create({String name = 'Ví tiền mặt', AccountType type = AccountType.cash, Money? initialBalance}) async {
    final result = await repository.createAccount(name: name, type: type, initialBalance: initialBalance ?? Money(1500000, 'VND'));

    return (result as GPOk<AccountEntity>).value;
  }

  /// Writes a row the mapper would refuse, straight through drift. Used to prove what a corrupt local row does to a read.
  Future<void> insertUnmappableRow(String id) => db
      .into(db.accountsTable)
      .insert(
        AccountsTableCompanion.insert(
          id: id,
          ownerId: localOwnerId,
          name: 'Ví hỏng',
          // Not a value `AccountType.fromStorage` knows. There is no CHECK on this column, which is exactly why the mapper has to guard it.
          type: 'savings',
          currencyCode: 'VND',
          initialBalance: 0,
          isArchived: false,
          createdAt: startedAt.millisecondsSinceEpoch,
          updatedAt: startedAt.millisecondsSinceEpoch,
          version: 1,
        ),
      );

  group('createAccount', () {
    test('create → watchAccounts emit', () async {
      // W2's done criterion, at the layer the UI will actually use.
      final created = await create();

      expect(await repository.watchAccounts().first, [created]);
    });

    test('mints the id client-side and stamps both timestamps from the clock', () async {
      final created = await create();

      // Golden rule 4: the id exists before the row does and no server hands it back.
      expect(created.id, uuid.issuedV7.single);
      // One clock read for the whole operation, so a fresh row's two timestamps are the same instant rather than two that happen to be close.
      expect(created.createdAt, startedAt);
      expect(created.updatedAt, startedAt);
      expect(created.version, 1);
    });

    test('writes the owner the repository was built with, not one the caller passed', () async {
      final created = await create();
      final row = await dao.findById(created.id);

      // The domain has no `ownerId` to get wrong; this is the only layer that states it.
      expect(row!.ownerId, localOwnerId);
    });

    test('refuses a blank name and writes nothing', () async {
      final result = await repository.createAccount(name: '  ', type: AccountType.cash, initialBalance: Money.zero('VND'));

      expect(result, const GPErr<AccountEntity>(GPValidationFailure(GPValidationCode.accountNameEmpty)));
      // The failure has to be *before* the insert, not a row that was written and then complained about.
      expect(await repository.watchAccounts().first, isEmpty);
    });

    test('keeps the currency with the amount', () async {
      final created = await create(initialBalance: Money(1234, 'USD'));
      final row = await dao.findById(created.id);

      expect(row!.initialBalance, 1234);
      expect(row.currencyCode, 'USD');
      expect((await repository.watchAccounts().first).single.initialBalance, Money(1234, 'USD'));
    });
  });

  group('watchAccounts', () {
    test('re-emits when an account is added', () async {
      final emissions = <List<AccountEntity>>[];
      final subscription = repository.watchAccounts().listen(emissions.add);
      // Lets the initial (empty) emission land before the write, so the two are distinguishable below.
      await pumpEventQueue();

      final created = await create();
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions.first, isEmpty);
      expect(emissions.last, [created]);
    });

    test('hides archived accounts by default and shows them on request', () async {
      final created = await create();
      await repository.archiveAccount(created.id);

      expect(await repository.watchAccounts().first, isEmpty);
      expect((await repository.watchAccounts(includeArchived: true).first).single.isArchived, isTrue);
    });

    test('never shows another owner an account', () async {
      await create();
      final otherOwner = AccountRepositoryImpl(dao: dao, clock: clock, uuidGenerator: uuid, logger: logger, ownerId: 'someone-else');

      // Changes nothing a user could see until W10, and that is precisely why it is asserted now rather than then.
      expect(await otherOwner.watchAccounts().first, isEmpty);
    });

    test('fails the whole list when one row cannot be mapped, rather than hiding it', () async {
      await create();
      await insertUnmappableRow('broken');

      // Skipping the bad row would leave the user with a list and a balance that are quietly missing an account — worse than an honest error state.
      await expectLater(repository.watchAccounts(), emitsError(const GPDatabaseFailure()));
    });

    test('puts a GPFailure on the error channel, so onError needs no type test', () async {
      await insertUnmappableRow('broken');

      final error = await repository.watchAccounts().first.then<Object?>((_) => null, onError: (Object e) => e);

      expect(error, isA<GPFailure>());
    });

    test('logs an unmappable row with an id and no user data', () async {
      await insertUnmappableRow('broken');
      await repository.watchAccounts().first.catchError((Object _) => <AccountEntity>[]);

      // Golden rule 9: an id and an entity type are exactly what a log line may hold. `Ví hỏng` is the row's name and must not appear.
      expect(logger.last.level, GPLogLevel.error);
      expect(logger.last.fields, {'entity': 'account', 'id': 'broken'});
    });
  });

  group('watchAccount', () {
    test('emits the account, then null once it is deleted', () async {
      final created = await create();
      final emissions = <AccountEntity?>[];
      final subscription = repository.watchAccount(created.id).listen(emissions.add);
      await pumpEventQueue();

      await repository.deleteAccount(created.id);
      await pumpEventQueue();
      await subscription.cancel();

      // Null is an ordinary emission, not an error: it is how a detail screen learns to pop itself.
      expect(emissions.first, created);
      expect(emissions.last, isNull);
    });

    test('emits null for an id that never existed', () async {
      expect(await repository.watchAccount('nope').first, isNull);
    });
  });

  group('updateAccount', () {
    test('applies the edit and moves updated_at without touching version', () async {
      final created = await create();
      clock.advance(const Duration(minutes: 5));

      final renamed = (await repository.updateAccount((created.update(name: 'Ví mới') as GPOk<AccountEntity>).value)) as GPOk<AccountEntity>;

      expect(renamed.value.name, 'Ví mới');
      // `updated_at` moves because W12's delta pull reads it; `version` does not, because it is the server's (§7).
      expect(renamed.value.updatedAt, startedAt.add(const Duration(minutes: 5)));
      expect(renamed.value.version, 1);
      expect(renamed.value.createdAt, startedAt);
    });

    test('stamps updated_at from the clock even when the caller passes a stale one', () async {
      final created = await create();
      clock.advance(const Duration(hours: 2));

      final updated = (await repository.updateAccount(created)) as GPOk<AccountEntity>;

      // A patch that skipped the pull cursor would produce a row that is locally correct and permanently invisible to sync.
      expect(updated.value.updatedAt, startedAt.add(const Duration(hours: 2)));
      expect((await dao.findById(created.id))!.updatedAt, startedAt.add(const Duration(hours: 2)).millisecondsSinceEpoch);
    });

    test('reports a conflict with the version that is actually stored', () async {
      final created = await create();
      // Stands in for a sync pull that advanced the row while this client held version 1.
      await dao.updateAccount(
        created.id,
        baseVersion: 1,
        patch: const AccountsTableCompanion(version: Value(4)),
        now: clock.nowEpochMillis(),
      );

      final result = await repository.updateAccount(created);

      expect(
        result,
        GPErr<AccountEntity>(GPConflictFailure(entityId: created.id, localVersion: 1, remoteVersion: 4)),
      );
    });

    test('reports a deleted row as not found, not as a conflict', () async {
      final created = await create();
      await repository.deleteAccount(created.id);

      // Both are zero-row outcomes and they need different words: "changed on another device" invites a reload, this one invites closing the screen.
      expect(await repository.updateAccount(created), const GPErr<AccountEntity>(GPNotFoundFailure()));
    });

    test('reports an id that was never there as not found', () async {
      final created = await create();
      await db.delete(db.accountsTable).go();

      expect(await repository.updateAccount(created), const GPErr<AccountEntity>(GPNotFoundFailure()));
    });

    test('an invalid edit never reaches this method — it is refused by the entity', () async {
      final created = await create();

      // There is no way to hand `updateAccount` a broken entity: `update` is the only way to change one and it refuses, so the form gets its message
      // without a database round trip. This is the assertion that keeps that true — if `update` ever stopped validating, the repository has no second net.
      expect(created.update(name: '  '), const GPErr<AccountEntity>(GPValidationFailure(GPValidationCode.accountNameEmpty)));
      expect(await repository.watchAccounts().first, [created]);
    });
  });

  group('archiveAccount / unarchiveAccount', () {
    test('archiving hides the account and un-archiving brings it back', () async {
      final created = await create();

      expect(await repository.archiveAccount(created.id), const GPOk<void>(null));
      expect(await repository.watchAccounts().first, isEmpty);

      expect(await repository.unarchiveAccount(created.id), const GPOk<void>(null));
      expect((await repository.watchAccounts().first).single.id, created.id);
    });

    test('archiving keeps the row and its version', () async {
      final created = await create();
      await repository.archiveAccount(created.id);
      final row = await dao.findById(created.id);

      // Archived is not deleted: the row keeps its history, keeps syncing, and its tombstone stays null.
      expect(row!.deletedAt, isNull);
      expect(row.isArchived, isTrue);
      expect(row.version, 1);
    });

    test('reports an unknown id as not found', () async {
      expect(await repository.archiveAccount('nope'), const GPErr<void>(GPNotFoundFailure()));
      expect(await repository.unarchiveAccount('nope'), const GPErr<void>(GPNotFoundFailure()));
    });
  });

  group('deleteAccount', () {
    test('soft-deletes: the row stays, stamped, and leaves the stream', () async {
      final created = await create();
      clock.advance(const Duration(minutes: 1));

      expect(await repository.deleteAccount(created.id), const GPOk<void>(null));

      final row = await dao.findById(created.id);
      // Golden rule 5: a hard delete would be a deletion the server never learns about.
      expect(row, isNotNull);
      expect(row!.deletedAt, startedAt.add(const Duration(minutes: 1)).millisecondsSinceEpoch);
      // `updated_at` moves too, or the deletion never reaches W12's delta pull.
      expect(row.updatedAt, row.deletedAt);
      expect(await repository.watchAccounts(includeArchived: true).first, isEmpty);
    });

    test('deleting twice reports not found the second time', () async {
      final created = await create();

      expect(await repository.deleteAccount(created.id), const GPOk<void>(null));
      expect(await repository.deleteAccount(created.id), const GPErr<void>(GPNotFoundFailure()));
    });
  });

  test('a rejected write surfaces as a database failure, not as a crash', () async {
    await create();
    // A second repository with its own generator, so it mints the id the first one already used. A primary-key collision is the most realistic local
    // write failure there is, and it arrives as a `SqliteException` — an `Exception`, which is exactly the class this layer is allowed to swallow.
    final collides = AccountRepositoryImpl(dao: dao, clock: clock, uuidGenerator: FakeUuidGenerator(), logger: logger, ownerId: localOwnerId);

    final result = await collides.createAccount(name: 'Ví', type: AccountType.cash, initialBalance: Money.zero('VND'));

    expect(result, const GPErr<AccountEntity>(GPDatabaseFailure()));
    expect(logger.last.level, GPLogLevel.error);
    // Rule 9, on the path where dumping the whole row into the log is most tempting: an id and an entity type, nothing else.
    expect(logger.last.fields.keys, ['entity', 'id']);
  });
}
