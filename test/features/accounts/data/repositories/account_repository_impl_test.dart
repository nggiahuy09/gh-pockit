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
import '../../../../helpers/results.dart';

final _startedAt = DateTime.utc(2026, 9, 18, 9);

Future<AccountEntity> _create(AccountRepositoryImpl repository, {Money? initialBalance, AccountType type = AccountType.cash, String name = 'Ví tiền mặt'}) async =>
    okValue(await repository.createAccount(initialBalance: initialBalance ?? Money(1500000, 'VND'), type: type, name: name));

/// `savings` is unknown to `AccountType.fromStorage`, and the column has no CHECK, so SQLite accepts it.
Future<void> _insertUnmappableRow(GPAppDatabase db, String id) => db
    .into(db.accountsTable)
    .insert(
      AccountsTableCompanion.insert(
        id: id,
        ownerId: localOwnerId,
        name: 'Ví hỏng',
        type: 'savings',
        currencyCode: 'VND',
        initialBalance: 0,
        isArchived: false,
        createdAt: _startedAt.millisecondsSinceEpoch,
        updatedAt: _startedAt.millisecondsSinceEpoch,
        version: 1,
      ),
    );

/// Real in-memory SQL, not a mocked DAO: a mock would only restate which DAO methods the repository calls.
void main() {
  late GPAppDatabase db;
  late AccountDao dao;
  late FakeClock clock;
  late FakeUuidGenerator uuid;
  late RecordingLogger logger;
  late AccountRepositoryImpl repository;

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    dao = AccountDao(db);
    clock = FakeClock(_startedAt);
    uuid = FakeUuidGenerator();
    logger = RecordingLogger(clock);
    repository = AccountRepositoryImpl(clock: clock, dao: dao, logger: logger, uuidGenerator: uuid, ownerId: localOwnerId);
  });

  tearDown(() => db.close());

  group('createAccount', () {
    test('create → watchAccounts emit', () async {
      final created = await _create(repository);

      expect(await repository.watchAccounts().first, [created]);
    });

    test('mints the id client-side and stamps both timestamps from the clock', () async {
      final created = await _create(repository);

      expect(created.id, uuid.issuedV7.single);
      expect(created.createdAt, _startedAt);
      expect(created.updatedAt, _startedAt);
      expect(created.version, 1);
    });

    test('writes the owner the repository was built with, not one the caller passed', () async {
      final created = await _create(repository);

      expect((await dao.findById(created.id))!.ownerId, localOwnerId);
    });

    test('refuses a blank name and writes nothing', () async {
      final result = await repository.createAccount(initialBalance: Money.zero('VND'), type: AccountType.cash, name: '  ');

      expect(result, const GPErr<AccountEntity>(GPValidationFailure(GPValidationCode.accountNameEmpty)));
      expect(await repository.watchAccounts().first, isEmpty);
    });

    test('keeps the currency with the amount', () async {
      final created = await _create(repository, initialBalance: Money(1234, 'USD'));
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
      await pumpEventQueue();

      final created = await _create(repository);
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions.first, isEmpty);
      expect(emissions.last, [created]);
    });

    test('hides archived accounts by default and shows them on request', () async {
      final created = await _create(repository);
      await repository.archiveAccount(created.id);

      expect(await repository.watchAccounts().first, isEmpty);
      expect((await repository.watchAccounts(true).first).single.isArchived, isTrue);
    });

    test('never shows another owner an account', () async {
      await _create(repository);
      final otherOwner = AccountRepositoryImpl(clock: clock, dao: dao, logger: logger, uuidGenerator: uuid, ownerId: 'someone-else');

      expect(await otherOwner.watchAccounts().first, isEmpty);
    });

    test('fails the whole list when one row cannot be mapped, rather than hiding it', () async {
      await _create(repository);
      await _insertUnmappableRow(db, 'broken');

      await expectLater(repository.watchAccounts(), emitsError(const GPDatabaseFailure()));
    });

    test('puts a GPFailure on the error channel, so onError needs no type test', () async {
      await _insertUnmappableRow(db, 'broken');

      final error = await repository.watchAccounts().first.then<Object?>((_) => null, onError: (Object error) => error);

      expect(error, isA<GPFailure>());
    });

    test('logs an unmappable row with an id and no user data', () async {
      await _insertUnmappableRow(db, 'broken');
      await repository.watchAccounts().first.catchError((Object _) => <AccountEntity>[]);

      expect(logger.last.level, GPLogLevel.error);
      expect(logger.last.fields, {'entity': 'account', 'id': 'broken', 'reason': 'unknownType'});
    });
  });

  group('watchAccount', () {
    test('emits the account, then null once it is deleted', () async {
      final created = await _create(repository);
      final emissions = <AccountEntity?>[];
      final subscription = repository.watchAccount(created.id).listen(emissions.add);
      await pumpEventQueue();

      await repository.deleteAccount(created.id);
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions.first, created);
      expect(emissions.last, isNull);
    });

    test('emits null for an id that never existed', () async {
      expect(await repository.watchAccount('nope').first, isNull);
    });
  });

  group('updateAccount', () {
    test('applies the edit and moves updated_at without touching version', () async {
      final created = await _create(repository);
      clock.advance(const Duration(minutes: 5));

      final renamed = okValue(await repository.updateAccount(okValue(created.update(name: 'Ví mới'))));

      expect(renamed.name, 'Ví mới');
      expect(renamed.updatedAt, _startedAt.add(const Duration(minutes: 5)));
      expect(renamed.version, 1);
      expect(renamed.createdAt, _startedAt);
    });

    test('stamps updated_at from the clock even when the caller passes a stale one', () async {
      final created = await _create(repository);
      clock.advance(const Duration(hours: 2));

      final updated = okValue(await repository.updateAccount(created));

      expect(updated.updatedAt, _startedAt.add(const Duration(hours: 2)));
      expect((await dao.findById(created.id))!.updatedAt, _startedAt.add(const Duration(hours: 2)).millisecondsSinceEpoch);
    });

    test('reports a conflict with the version that is actually stored', () async {
      final created = await _create(repository);
      // Stands in for a sync pull that advanced the row while this client held version 1.
      await dao.updateAccount(
        created.id,
        patch: const AccountsTableCompanion(version: Value(4)),
        baseVersion: 1,
        now: clock.nowEpochMillis(),
      );

      expect(await repository.updateAccount(created), GPErr<AccountEntity>(GPConflictFailure(entityId: created.id, localVersion: 1, remoteVersion: 4)));
    });

    test('reports a deleted row as not found, not as a conflict', () async {
      final created = await _create(repository);
      await repository.deleteAccount(created.id);

      expect(await repository.updateAccount(created), const GPErr<AccountEntity>(GPNotFoundFailure()));
    });

    test('reports an id that was never there as not found', () async {
      final created = await _create(repository);
      await db.delete(db.accountsTable).go();

      expect(await repository.updateAccount(created), const GPErr<AccountEntity>(GPNotFoundFailure()));
    });

    test('an invalid edit never reaches this method — it is refused by the entity', () async {
      final created = await _create(repository);

      expect(created.update(name: '  '), const GPErr<AccountEntity>(GPValidationFailure(GPValidationCode.accountNameEmpty)));
      expect(await repository.watchAccounts().first, [created]);
    });
  });

  group('archiveAccount / unarchiveAccount', () {
    test('archiving hides the account and un-archiving brings it back', () async {
      final created = await _create(repository);

      expect(await repository.archiveAccount(created.id), const GPOk<void>(null));
      expect(await repository.watchAccounts().first, isEmpty);

      expect(await repository.unarchiveAccount(created.id), const GPOk<void>(null));
      expect((await repository.watchAccounts().first).single.id, created.id);
    });

    test('archiving keeps the row and its version', () async {
      final created = await _create(repository);
      await repository.archiveAccount(created.id);
      final row = await dao.findById(created.id);

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
      final created = await _create(repository);
      clock.advance(const Duration(minutes: 1));

      expect(await repository.deleteAccount(created.id), const GPOk<void>(null));

      final row = await dao.findById(created.id);
      expect(row, isNotNull);
      expect(row!.deletedAt, _startedAt.add(const Duration(minutes: 1)).millisecondsSinceEpoch);
      expect(row.updatedAt, row.deletedAt);
      expect(await repository.watchAccounts(true).first, isEmpty);
    });

    test('deleting twice reports not found the second time', () async {
      final created = await _create(repository);

      expect(await repository.deleteAccount(created.id), const GPOk<void>(null));
      expect(await repository.deleteAccount(created.id), const GPErr<void>(GPNotFoundFailure()));
    });
  });

  group('a write the database refuses', () {
    // A real database does not fail on request, so the `catch` sites are reached through a DAO that throws.
    late Object thrown;
    late AccountRepositoryImpl failing;

    setUp(() {
      thrown = Exception('disk full');
      failing = AccountRepositoryImpl(clock: clock, dao: _ThrowingAccountDao(db, () => thrown), logger: logger, uuidGenerator: uuid, ownerId: localOwnerId);
    });

    test('createAccount reports it and logs an id, not the row', () async {
      final result = await failing.createAccount(initialBalance: Money(1500000, 'VND'), type: AccountType.cash, name: 'Ví tiền mặt');

      expect(result, const GPErr<AccountEntity>(GPDatabaseFailure()));
      expect(logger.last.level, GPLogLevel.error);
      expect(logger.last.fields.keys, ['entity', 'id']);
    });

    test('updateAccount reports it, rolling the transaction back', () async {
      final created = await _create(repository);

      expect(await failing.updateAccount(created), const GPErr<AccountEntity>(GPDatabaseFailure()));
      expect((await dao.findById(created.id))!.name, created.name);
    });

    test('the unguarded writes report it too', () async {
      // `archiveAccount`, `unarchiveAccount` and `deleteAccount` share one `catch` site; this covers it.
      expect(await failing.archiveAccount('a1'), const GPErr<void>(GPDatabaseFailure()));
      expect(logger.last.fields['id'], 'a1');
    });

    test('a real primary-key collision is a database failure like any other', () async {
      await _create(repository);
      // A fresh FakeUuidGenerator mints the id the first repository already used.
      final collides = AccountRepositoryImpl(clock: clock, dao: dao, logger: logger, uuidGenerator: FakeUuidGenerator(), ownerId: localOwnerId);

      final result = await collides.createAccount(initialBalance: Money.zero('VND'), type: AccountType.cash, name: 'Ví');

      expect(result, const GPErr<AccountEntity>(GPDatabaseFailure()));
    });

    test('an Error is not swallowed — it is a bug and must reach the crash reporter', () async {
      thrown = StateError('broken invariant');

      await expectLater(failing.createAccount(initialBalance: Money.zero('VND'), type: AccountType.cash, name: 'Ví'), throwsA(isA<StateError>()));
      expect(logger.records, isEmpty);
    });
  });

  group('a read the database refuses', () {
    test('a query SQLite refuses reaches the caller as a GPDatabaseFailure, not as a raw SqliteException', () async {
      // No double: a dropped table fails the real query the way a corrupt file or a failed migration would.
      await db.customStatement('DROP TABLE accounts');

      await expectLater(repository.watchAccounts(), emitsError(const GPDatabaseFailure()));
      expect(logger.last.error, isA<SqliteException>());
    });

    test('watchAccounts reports an exception and logs an entity type, nothing else', () async {
      final failing = AccountRepositoryImpl(
        clock: clock,
        dao: _FailingStreamAccountDao(db, SqliteException(10, 'disk I/O error')),
        logger: logger,
        uuidGenerator: uuid,
        ownerId: localOwnerId,
      );

      await expectLater(failing.watchAccounts(), emitsError(const GPDatabaseFailure()));
      expect(logger.last.level, GPLogLevel.error);
      expect(logger.last.fields, {'entity': 'account'});
    });

    test('watchAccount reports it too, and logs the id', () async {
      final failing = AccountRepositoryImpl(
        clock: clock,
        dao: _FailingStreamAccountDao(db, SqliteException(10, 'disk I/O error')),
        logger: logger,
        uuidGenerator: uuid,
        ownerId: localOwnerId,
      );

      await expectLater(failing.watchAccount('a1'), emitsError(const GPDatabaseFailure()));
      expect(logger.last.fields, {'entity': 'account', 'id': 'a1'});
    });

    test('an Error is forwarded unchanged — it is a bug and must reach the crash reporter', () async {
      final bug = StateError('broken invariant');
      final failing = AccountRepositoryImpl(clock: clock, dao: _FailingStreamAccountDao(db, bug), logger: logger, uuidGenerator: uuid, ownerId: localOwnerId);

      await expectLater(failing.watchAccounts(), emitsError(same(bug)));
      await expectLater(failing.watchAccount('a1'), emitsError(same(bug)));
      expect(logger.records, isEmpty);
    });
  });
}

/// Subclasses the real DAO so `transaction()` and every read still run against the in-memory database; only the writes fail.
final class _ThrowingAccountDao extends AccountDao {
  _ThrowingAccountDao(super.attachedDatabase, this._thrown);

  final Object Function() _thrown;

  @override
  Future<void> insertAccount(AccountsTableCompanion row) => Future.error(_thrown.call());

  @override
  Future<int> updateAccount(String id, {required AccountsTableCompanion patch, required int baseVersion, required int now}) => Future.error(_thrown.call());

  @override
  Future<int> archive(String id, {required int now}) => Future.error(_thrown.call());
}

/// `Stream.error`, not a throw: drift puts a watched query's failure on the stream's error channel.
final class _FailingStreamAccountDao extends AccountDao {
  _FailingStreamAccountDao(super.attachedDatabase, this._error);

  final Object _error;

  @override
  Stream<List<AccountRow>> watchAccounts(String ownerId, {bool includeArchived = false}) => Stream.error(_error);

  @override
  Stream<AccountRow?> watchAccount({required String id, required String ownerId}) => Stream.error(_error);
}
