import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/sync/drift_sync_queue_repository.dart';
import 'package:ghpockit/features/accounts/data/daos/account_dao.dart';
import 'package:ghpockit/features/accounts/data/mapper/account_mapper.dart';
import 'package:ghpockit/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/categories/data/daos/category_dao.dart';
import 'package:ghpockit/features/categories/data/mapper/category_mapper.dart';
import 'package:ghpockit/features/categories/data/repositories/category_repository_impl.dart';
import 'package:ghpockit/features/categories/data/seed/category_seeder.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/data/mapper/transaction_mapper.dart';
import 'package:ghpockit/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/fake_uuid_generator.dart';
import '../../helpers/fixed_owner_context.dart';
import '../../helpers/recording_logger.dart';
import '../../helpers/results.dart';
import '../../helpers/sync_queue.dart';

const _user = 'uid-1';
const _steps = 300;

typedef _Entity = (String type, String id);

/// The outbox's core invariant (blueprint App. D, ADR-0044): an entity that exists here and needs sync has a mutation, and the newest one
/// carries the row as it is now. Checked after every step of a seeded random mix of every write path and of what a push does to the queue.
void main() {
  late GPAppDatabase db;
  late FakeClock clock;
  late GPDriftSyncQueueRepository queue;
  late AccountRepositoryImpl accounts;
  late CategoryRepositoryImpl categories;
  late TransactionRepositoryImpl transactions;
  late CategorySeeder seeder;

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    clock = FakeClock(DateTime.utc(2026, 11, 27, 3));
    final logger = RecordingLogger(clock);
    final owner = FixedOwnerContext(_user);
    queue = syncQueueOn(db, clock);
    accounts = AccountRepositoryImpl(clock: clock, dao: AccountDao(db), logger: logger, uuidGenerator: FakeUuidGenerator('acc'), ownerContext: owner, syncQueue: queue);
    categories = CategoryRepositoryImpl(clock: clock, dao: CategoryDao(db), logger: logger, uuidGenerator: FakeUuidGenerator('cat'), ownerContext: owner, syncQueue: queue);
    transactions = TransactionRepositoryImpl(clock: clock, dao: TransactionDao(db), logger: logger, uuidGenerator: FakeUuidGenerator('tx'), ownerContext: owner, syncQueue: queue);
    seeder = CategorySeeder(clock: clock, dao: CategoryDao(db), ownerContext: owner, uuidGenerator: FakeUuidGenerator('seed'), syncQueue: queue);
  });

  tearDown(() => db.close());

  Future<Map<_Entity, Map<String, Object?>>> rowsNow() async => {
    for (final row in await db.select(db.accountsTable).get()) ('account', row.id): row.toSyncPayload(),
    for (final row in await db.select(db.categoriesTable).get()) ('category', row.id): row.toSyncPayload(),
    for (final row in await db.select(db.transactionsTable).get()) ('transaction', row.id): row.toSyncPayload(),
  };

  // In the order queued: the fake v7 ids do not sort past nine as real ones do.
  Future<List<SyncMutationRow>> mutations() =>
      db.customSelect('SELECT * FROM sync_mutations ORDER BY rowid', readsFrom: {db.syncMutationsTable}).map((row) => db.syncMutationsTable.map(row.data)).get();

  Future<void> expectInvariant(Set<_Entity> dirty, String step) async {
    final rows = await rowsNow();
    final byEntity = <_Entity, List<SyncMutationRow>>{};
    for (final mutation in await mutations()) {
      (byEntity[(mutation.entityType, mutation.entityId)] ??= []).add(mutation);
    }

    for (final MapEntry(key: entity, value: row) in rows.entries) {
      final queued = byEntity[entity];
      if (!dirty.contains(entity)) {
        expect(queued, isNull, reason: '$step: $entity is synced, yet still queued');
        continue;
      }
      expect(queued, isNotNull, reason: '$step: $entity needs sync and has no mutation');
      expect(jsonDecode(queued!.last.payloadJson), row, reason: '$step: the newest mutation of $entity is not the row as it is');
      expect(queued.where((m) => m.status == 'pending' && m.attemptCount == 0), hasLength(lessThanOrEqualTo(1)), reason: '$step: $entity has two unsent');
    }
    expect(byEntity.keys.where((entity) => !rows.containsKey(entity)), isEmpty, reason: '$step: a mutation for a row that is not here');
  }

  group('every entity that needs sync has a mutation carrying the row as it is now', () {
    for (final seed in [1, 2, 3]) {
      test('$_steps random writes and pushes, seed $seed', () async {
        final random = Random(seed);
        final dirty = <_Entity>{};
        final done = <String>{};
        T pick<T>(List<T> from) => from[random.nextInt(from.length)];
        void wrote(GPResult<Object?> result, _Entity entity) {
          if (result is GPOk) dirty.add(entity);
        }

        await seeder.seedDefaults();
        for (final row in await db.select(db.categoriesTable).get()) {
          dirty.add(('category', row.id));
        }
        await expectInvariant(dirty, 'seed');

        for (var step = 1; step <= _steps; step++) {
          clock.advance(Duration(seconds: 1 + random.nextInt(30)));
          final accountRows = await db.select(db.accountsTable).get();
          final categoryRows = await db.select(db.categoriesTable).get();
          final transactionRows = await db.select(db.transactionsTable).get();
          final queued = await mutations();
          final String action;

          switch (random.nextInt(16)) {
            case 0 when accountRows.length < 5:
              action = 'create account';
              final result = await accounts.createAccount(initialBalance: Money(random.nextInt(1000000), 'VND'), type: AccountType.cash, name: 'Ví $step');
              if (result case GPOk(:final value)) dirty.add(('account', value.id));
            case 1 when accountRows.isNotEmpty:
              action = 'rename account';
              final row = pick(accountRows);
              final entity = (row.toDomain() as MappedAccount).account;
              wrote(await accounts.updateAccount(okValue(entity.update(name: 'Ví $step'))), ('account', row.id));
            case 2 when accountRows.isNotEmpty:
              action = 'archive or unarchive account';
              final row = pick(accountRows);
              wrote(await (row.isArchived ? accounts.unarchiveAccount(row.id) : accounts.archiveAccount(row.id)), ('account', row.id));
            case 3 when accountRows.isNotEmpty && random.nextInt(4) == 0:
              action = 'delete account';
              final row = pick(accountRows);
              wrote(await accounts.deleteAccount(row.id), ('account', row.id));
            case 4:
              action = 'create category';
              final result = await categories.createCategory(type: CategoryType.expense, name: 'Danh mục $step');
              if (result case GPOk(:final value)) dirty.add(('category', value.id));
            case 5 when categoryRows.isNotEmpty:
              action = 'rename category';
              final row = pick(categoryRows);
              final entity = (row.toDomain() as MappedCategory).category;
              wrote(await categories.updateCategory(okValue(entity.update(name: 'Tên $step'))), ('category', row.id));
            case 6 when categoryRows.isNotEmpty && random.nextInt(3) == 0:
              action = 'delete category';
              final row = pick(categoryRows);
              wrote(await categories.deleteCategory(row.id), ('category', row.id));
            case 7 || 8 when accountRows.isNotEmpty:
              action = 'create transaction';
              final result = await transactions.createTransaction(
                amount: Money(1 + random.nextInt(500000), 'VND'),
                type: TransactionType.expense,
                occurredAt: clock.nowUtc(),
                accountId: pick(accountRows).id,
                categoryId: categoryRows.isEmpty || random.nextBool() ? null : pick(categoryRows).id,
              );
              if (result case GPOk(:final value)) dirty.add(('transaction', value.id));
            case 9 when transactionRows.isNotEmpty:
              action = 'change a transaction amount';
              final row = pick(transactionRows);
              final entity = (row.toDomain() as MappedTransaction).transaction;
              final changed = okValue(entity.update(amount: Money(1 + random.nextInt(500000), 'VND')));
              wrote(await transactions.updateTransaction(changed), ('transaction', row.id));
            case 10 when transactionRows.isNotEmpty:
              action = 'delete or restore a transaction';
              final row = pick(transactionRows);
              wrote(await (row.deletedAt == null ? transactions.deleteTransaction(row.id) : transactions.restoreTransaction(row.id)), ('transaction', row.id));
            case 11 || 12:
              // Whatever the queue hands out: it keeps each entity's mutations in order itself.
              action = 'send';
              final ready = await queue.getReadyMutations(limit: 200);
              if (ready.isNotEmpty) await queue.markSending(pick(ready).id);
            case 13 when queued.any((m) => m.status == 'processing'):
              action = 'acknowledge';
              final sent = pick(queued.where((m) => m.status == 'processing').toList());
              await queue.complete(sent.id);
              final entity = (sent.entityType, sent.entityId);
              if ((await mutations()).every((m) => (m.entityType, m.entityId) != entity)) dirty.remove(entity);
            case 14 when queued.any((m) => m.status == 'processing'):
              action = random.nextInt(3) == 0 ? 'fail' : 'retry';
              final sent = pick(queued.where((m) => m.status == 'processing').toList());
              if (action == 'fail') {
                await queue.markFailed(sent.id, errorCode: 'validation');
              } else {
                await queue.scheduleRetry(sent.id, nextAttemptAt: clock.nowUtc(), errorCode: 'network');
              }
            case 15:
              action = 'relaunch';
              await queue.resetOrphans();
            default:
              action = 'nothing';
          }

          await expectInvariant(dirty, 'step $step ($action)');
          done.add(action);
        }

        // The walk reached every path it claims to.
        expect(
          done,
          containsAll(<String>[
            'create account',
            'rename account',
            'archive or unarchive account',
            'delete account',
            'create category',
            'rename category',
            'delete category',
            'create transaction',
            'change a transaction amount',
            'delete or restore a transaction',
            'send',
            'acknowledge',
            'retry',
            'fail',
            'relaunch',
          ]),
        );
      });
    }
  });
}
