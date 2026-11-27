import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/settings_owner_context.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/sync/drift_sync_queue_repository.dart';
import 'package:ghpockit/core/sync/sync_entity_type.dart';
import 'package:ghpockit/core/sync/sync_mutation.dart';
import 'package:ghpockit/core/sync/sync_operation.dart';
import 'package:ghpockit/core/sync/sync_queue_repository.dart';
import 'package:ghpockit/features/accounts/data/daos/account_dao.dart';
import 'package:ghpockit/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/auth/data/daos/device_owner_dao.dart';
import 'package:ghpockit/features/auth/data/repositories/device_owner_repository_impl.dart';
import 'package:ghpockit/features/categories/data/daos/category_dao.dart';
import 'package:ghpockit/features/categories/data/repositories/category_repository_impl.dart';
import 'package:ghpockit/features/categories/data/seed/category_seeder.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/fake_uuid_generator.dart';
import '../../helpers/fixed_owner_context.dart';
import '../../helpers/recording_logger.dart';
import '../../helpers/results.dart';
import '../../helpers/sync_queue.dart';

const _user = 'uid-1';
const _tables = ['settings', 'accounts', 'categories', 'transactions', 'sync_mutations', 'sync_metadata'];

/// A crash after the entity write and its mutation, before the commit: both must go, on every write path (golden rule 3). The crash is the
/// queue throwing once its own insert is done, which is the last thing inside each write's transaction.
void main() {
  late GPAppDatabase db;
  late FakeClock clock;
  late RecordingLogger logger;
  late _CrashingQueue queue;
  late AccountRepositoryImpl accounts;
  late CategoryRepositoryImpl categories;
  late TransactionRepositoryImpl transactions;
  late CategorySeeder seeder;

  setUp(() {
    db = GPAppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    clock = FakeClock(DateTime.utc(2026, 11, 27, 3));
    logger = RecordingLogger(clock);
    queue = _CrashingQueue(syncQueueOn(db, clock));
    final owner = FixedOwnerContext(_user);
    accounts = AccountRepositoryImpl(clock: clock, dao: AccountDao(db), logger: logger, uuidGenerator: FakeUuidGenerator('acc'), ownerContext: owner, syncQueue: queue);
    categories = CategoryRepositoryImpl(clock: clock, dao: CategoryDao(db), logger: logger, uuidGenerator: FakeUuidGenerator('cat'), ownerContext: owner, syncQueue: queue);
    transactions = TransactionRepositoryImpl(clock: clock, dao: TransactionDao(db), logger: logger, uuidGenerator: FakeUuidGenerator('tx'), ownerContext: owner, syncQueue: queue);
    seeder = CategorySeeder(clock: clock, dao: CategoryDao(db), ownerContext: owner, uuidGenerator: FakeUuidGenerator('seed'), syncQueue: queue);
  });

  tearDown(() => db.close());

  Future<Map<String, List<Map<String, Object?>>>> snapshot() async => {
    for (final table in _tables) table: (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get()).map((row) => row.data).toList(),
  };

  /// An account, a category, a live and a deleted transaction, an archived account: something for every path to change.
  Future<({String account, String archived, String category, String live, String deleted})> given() async {
    final account = okValue(await accounts.createAccount(initialBalance: Money(500000, 'VND'), type: AccountType.cash, name: 'Ví'));
    final archived = okValue(await accounts.createAccount(initialBalance: Money(0, 'VND'), type: AccountType.bank, name: 'VCB'));
    okValue(await accounts.archiveAccount(archived.id));
    final category = okValue(await categories.createCategory(type: CategoryType.expense, name: 'Cà phê'));
    Future<String> spend() async => okValue(
      await transactions.createTransaction(amount: Money(45000, 'VND'), type: TransactionType.expense, occurredAt: clock.nowUtc(), accountId: account.id, categoryId: category.id),
    ).id;
    final live = await spend();
    final deleted = await spend();
    okValue(await transactions.deleteTransaction(deleted));
    clock.advance(const Duration(minutes: 1));
    return (account: account.id, archived: archived.id, category: category.id, live: live, deleted: deleted);
  }

  final paths = <String, Future<Object?> Function(({String account, String archived, String category, String live, String deleted}) ids)>{
    'create an account': (_) => accounts.createAccount(initialBalance: Money(0, 'VND'), type: AccountType.cash, name: 'Ví mới'),
    'update an account': (ids) async {
      final account = (await accounts.watchAccount(ids.account).first)!;
      return accounts.updateAccount(okValue(account.update(name: 'Ví chính')));
    },
    'archive an account': (ids) => accounts.archiveAccount(ids.account),
    'unarchive an account': (ids) => accounts.unarchiveAccount(ids.archived),
    'delete an account': (ids) => accounts.deleteAccount(ids.account),
    'create a category': (_) => categories.createCategory(type: CategoryType.income, name: 'Thưởng'),
    'update a category': (ids) async {
      final category = (await categories.watchCategory(ids.category).first)!;
      return categories.updateCategory(okValue(category.update(name: 'Trà')));
    },
    'delete a category': (ids) => categories.deleteCategory(ids.category),
    'create a transaction': (ids) => transactions.createTransaction(amount: Money(9000, 'VND'), type: TransactionType.expense, occurredAt: clock.nowUtc(), accountId: ids.account),
    'update a transaction': (ids) async {
      final transaction = (await transactions.watchTransaction(ids.live).first)!;
      return transactions.updateTransaction(okValue(transaction.update(amount: Money(99000, 'VND'))));
    },
    'delete a transaction': (ids) => transactions.deleteTransaction(ids.live),
    'restore a transaction': (ids) => transactions.restoreTransaction(ids.deleted),
    'seed the default categories': (_) => seeder.seedDefaults(),
  };

  group('a crash between the mutation and the commit keeps neither', () {
    for (final MapEntry(key: name, value: write) in paths.entries) {
      test(name, () async {
        final ids = await given();
        final before = await snapshot();
        queue.crashWith = Exception('killed before commit');

        final outcome = await write(ids).then<Object?>((value) => value, onError: (Object error) => error);

        expect(queue.crashes, 1, reason: 'the write reached its enqueue');
        // A repository maps the exception to a failure; the seeder lets it through to the bootstrap's handler.
        expect(outcome, anyOf(isA<GPErr<dynamic>>().having((err) => err.failure, 'failure', const GPDatabaseFailure()), same(queue.crashWith)));
        expect(await snapshot(), before);
      });
    }

    test('a bug (an Error, not an Exception) rolls back just the same, and reaches the caller', () async {
      final ids = await given();
      final before = await snapshot();
      queue.crashWith = StateError('broken invariant');

      await expectLater(paths['create a transaction']!(ids), throwsStateError);

      expect(await snapshot(), before);
    });

    test('the same write with no crash commits both, so the crash is what undid them', () async {
      final ids = await given();
      final before = await snapshot();

      okValue(await transactions.deleteTransaction(ids.live));

      final after = await snapshot();
      expect(after['transactions'], isNot(before['transactions']));
      expect(after['sync_mutations'], isNot(before['sync_mutations']));
    });

    test('the claim: every row stays local, nothing is queued, the owner is not set', () async {
      final owner = GPSettingsOwnerContext(database: db, logger: logger);
      addTearDown(owner.dispose);
      await owner.load();
      final local = AccountRepositoryImpl(clock: clock, dao: AccountDao(db), logger: logger, uuidGenerator: FakeUuidGenerator('loc'), ownerContext: owner, syncQueue: queue);
      okValue(await local.createAccount(initialBalance: Money(0, 'VND'), type: AccountType.cash, name: 'Ví'));
      final deviceOwner = DeviceOwnerRepositoryImpl(
        clock: clock,
        dao: DeviceOwnerDao(db),
        logger: logger,
        ownerContext: owner,
        seeder: seeder,
        uuidGenerator: FakeUuidGenerator('claim'),
        syncQueue: queue,
      );
      final before = await snapshot();
      queue.crashWith = Exception('killed before commit');

      expect(await deviceOwner.claimLocalData(_user), const GPErr<int>(GPDatabaseFailure()));

      expect(await snapshot(), before);
      expect(owner.current, isNot(_user));
    });
  });
}

/// Enqueues for real, then throws: the state a kill leaves just before the transaction would have committed.
final class _CrashingQueue implements GPSyncQueueRepository {
  _CrashingQueue(this._inner);

  final GPDriftSyncQueueRepository _inner;

  /// Null: no crash. Set: every enqueue writes, then throws this.
  Object? crashWith;
  int crashes = 0;

  @override
  Future<GPSyncMutation> enqueue({
    required GPSyncEntityType entityType,
    required String entityId,
    required GPSyncOperation operation,
    required Map<String, Object?> payload,
  }) async {
    final queued = await _inner.enqueue(entityType: entityType, entityId: entityId, operation: operation, payload: payload);
    switch (crashWith) {
      case final Exception exception:
        crashes++;
        throw exception;
      case final Error error:
        crashes++;
        throw error;
      default:
        return queued;
    }
  }

  @override
  Future<int> enqueueAll(List<GPSyncEnqueue> writes) async {
    final queued = await _inner.enqueueAll(writes);
    switch (crashWith) {
      case final Exception exception:
        crashes++;
        throw exception;
      case final Error error:
        crashes++;
        throw error;
      default:
        return queued;
    }
  }

  @override
  Future<List<GPSyncMutation>> getReadyMutations({int limit = GPDriftSyncQueueRepository.defaultReadyLimit}) => _inner.getReadyMutations(limit: limit);

  @override
  Future<GPSyncMutation?> markSending(String id) => _inner.markSending(id);

  @override
  Future<void> complete(String id) => _inner.complete(id);

  @override
  Future<void> scheduleRetry(String id, {required DateTime nextAttemptAt, required String errorCode}) =>
      _inner.scheduleRetry(id, nextAttemptAt: nextAttemptAt, errorCode: errorCode);

  @override
  Future<void> markConflict(String id, {required String errorCode}) => _inner.markConflict(id, errorCode: errorCode);

  @override
  Future<void> markFailed(String id, {required String errorCode}) => _inner.markFailed(id, errorCode: errorCode);

  @override
  Future<int> resetOrphans() => _inner.resetOrphans();

  @override
  Future<int> countUnsyncedEntities() => _inner.countUnsyncedEntities();
}
