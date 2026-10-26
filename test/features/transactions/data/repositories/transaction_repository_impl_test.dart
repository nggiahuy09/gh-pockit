import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/logging/app_logger.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_list_snapshot.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/fake_uuid_generator.dart';
import '../../../../helpers/recording_logger.dart';
import '../../../../helpers/results.dart';

final _startedAt = DateTime.utc(2026, 9, 28, 9);
final _occurredAt = DateTime.utc(2026, 9, 28, 5, 30);
const _otherOwner = 'someone-else';

/// Real in-memory SQL with the real DAO, not a mock: a mock would only restate which DAO methods the repository calls.
void main() {
  late GPAppDatabase db;
  late FakeClock clock;
  late TransactionDao dao;
  late RecordingLogger logger;
  late FakeUuidGenerator uuid;
  late TransactionRepositoryImpl repository;

  setUp(() async {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    dao = TransactionDao(db);
    clock = FakeClock(_startedAt);
    uuid = FakeUuidGenerator();
    logger = RecordingLogger(clock);
    repository = _repositoryOver(dao, clock: clock, logger: logger, uuid: uuid);

    await _insertAccount(db, 'acc-cash');
    await _insertAccount(db, 'acc-bank');
    await _insertAccount(db, 'acc-usd', currencyCode: 'USD');
    await _insertAccount(db, 'acc-archived', isArchived: true);
    await _insertAccount(db, 'acc-theirs', ownerId: _otherOwner);
    await db
        .into(db.categoriesTable)
        .insert(
          CategoriesTableCompanion.insert(
            id: 'cat-food',
            ownerId: localOwnerId,
            nameKey: const Value('category.food'),
            type: 'expense',
            isSystem: true,
            createdAt: 0,
            updatedAt: 0,
            version: 1,
          ),
        );
  });

  tearDown(() => db.close());

  group('createTransaction', () {
    test('writes the transaction and returns it as stored — id minted, both timestamps from the clock', () async {
      final created = okValue(await _create(repository, note: 'Phở bò'));

      expect(created.id, 'id-v7-1');
      expect(created.createdAt, _startedAt);
      expect(created.updatedAt, _startedAt);
      expect(created.version, 1);

      final stored = (await _storedRows(db)).single;
      expect(stored.id, created.id);
      expect(stored.ownerId, localOwnerId);
      expect(stored.amountMinor, 125000);
      expect(stored.currencyCode, 'VND');
      expect(stored.occurredAt, _occurredAt.millisecondsSinceEpoch);
      expect(stored.note, 'Phở bò');
      expect(stored.syncStatus, 'pending');
    });

    test('an entity rule refuses before the database is touched', () async {
      expect(await _create(repository, amount: Money.zero('VND')), _refusedBy(const GPValidationFailure(GPValidationCode.transactionAmountNotPositive)));
      expect(await _create(repository, type: TransactionType.transfer), _refusedBy(const GPValidationFailure(GPValidationCode.transactionDestinationMissing)));
      expect(await _storedRows(db), isEmpty);
    });

    test('refuses an account that is missing, deleted, or not the owner’s — as not found', () async {
      await _softDeleteAccount(db, 'acc-bank');

      expect(await _create(repository, accountId: 'acc-missing'), _refusedBy(const GPNotFoundFailure()));
      expect(await _create(repository, accountId: 'acc-bank'), _refusedBy(const GPNotFoundFailure()));
      expect(await _create(repository, accountId: 'acc-theirs'), _refusedBy(const GPNotFoundFailure()));
      expect(await _storedRows(db), isEmpty);
    });

    test('accepts an archived account', () async {
      expect(await _create(repository, accountId: 'acc-archived'), isA<GPOk<TransactionEntity>>());
    });

    test('refuses an amount in another currency than the account’s', () async {
      expect(await _create(repository, amount: Money(1234, 'USD')), _refusedBy(const GPValidationFailure(GPValidationCode.transactionCurrencyMismatch)));
      expect(await _storedRows(db), isEmpty);
    });

    test('refuses a transfer into a deleted account, and one between two currencies', () async {
      await _softDeleteAccount(db, 'acc-bank');

      expect(await _create(repository, type: TransactionType.transfer, destinationAccountId: 'acc-bank'), _refusedBy(const GPNotFoundFailure()));
      expect(
        await _create(repository, type: TransactionType.transfer, destinationAccountId: 'acc-usd'),
        _refusedBy(const GPValidationFailure(GPValidationCode.transactionTransferCurrenciesDiffer)),
      );
      expect(await _storedRows(db), isEmpty);
    });

    test('writes a transfer between two live accounts of one currency', () async {
      // `create` passes `cat-food` by default, so this transfer arrives with a category.
      final created = okValue(await _create(repository, type: TransactionType.transfer, destinationAccountId: 'acc-bank'));

      final stored = (await _storedRows(db)).single;
      expect(stored.destinationAccountId, 'acc-bank');
      expect(stored.categoryId, isNull);
      expect(created.categoryId, isNull);
    });

    test('a category that does not exist is a database failure — the foreign key refuses it', () async {
      expect(await _create(repository, categoryId: 'cat-ghost'), _refusedBy(const GPDatabaseFailure()));
      expect(logger.last.fields, {'entity': 'transaction', 'id': 'id-v7-1'});
    });
  });

  group('updateTransaction', () {
    test('applies the edit, stamps updated_at from the clock, and leaves version alone', () async {
      final created = okValue(await _create(repository));
      clock.advance(const Duration(minutes: 5));

      final updated = okValue(await repository.updateTransaction(okValue(created.update(amount: Money(95000, 'VND'), note: 'Bún chả'))));

      expect(updated.updatedAt, _startedAt.add(const Duration(minutes: 5)));
      final stored = (await _storedRows(db)).single;
      expect(stored.amountMinor, 95000);
      expect(stored.note, 'Bún chả');
      expect(stored.updatedAt, updated.updatedAt.millisecondsSinceEpoch);
      expect(stored.version, 1);
      expect(stored.syncStatus, 'pending');
    });

    test('switches an expense to a transfer in storage, clearing its category', () async {
      final created = okValue(await _create(repository));

      await repository.updateTransaction(okValue(created.update(type: TransactionType.transfer, destinationAccountId: 'acc-bank')));

      final stored = (await _storedRows(db)).single;
      expect(stored.type, 'transfer');
      expect(stored.destinationAccountId, 'acc-bank');
      expect(stored.categoryId, isNull);
    });

    test('reports a conflict with the version that is actually stored', () async {
      final created = okValue(await _create(repository));
      // Stands in for another device's edit, as a sync pull would apply it.
      await (db.update(db.transactionsTable)..where((t) => t.id.equals(created.id))).write(const TransactionsTableCompanion(version: Value(2)));

      final result = await repository.updateTransaction(okValue(created.update(note: 'Bún chả')));

      expect(result, _refusedBy(GPConflictFailure(entityId: created.id, localVersion: 1, remoteVersion: 2)));
      expect((await _storedRows(db)).single.note, isNull);
    });

    test('reports a deleted transaction as not found, not as a conflict', () async {
      final created = okValue(await _create(repository));
      await dao.softDelete(created.id, now: 1);

      expect(await repository.updateTransaction(created), _refusedBy(const GPNotFoundFailure()));
    });

    test('refuses when the account was deleted after the form opened', () async {
      final created = okValue(await _create(repository));
      await _softDeleteAccount(db, 'acc-cash');

      expect(await repository.updateTransaction(okValue(created.update(note: 'Bún chả'))), _refusedBy(const GPNotFoundFailure()));
      expect((await _storedRows(db)).single.note, isNull);
    });

    test('refuses when the account’s currency changed after the form opened', () async {
      final created = okValue(await _create(repository));
      await (db.update(db.accountsTable)..where((t) => t.id.equals('acc-cash'))).write(const AccountsTableCompanion(currencyCode: Value('USD')));

      expect(
        await repository.updateTransaction(okValue(created.update(note: 'Bún chả'))),
        _refusedBy(const GPValidationFailure(GPValidationCode.transactionCurrencyMismatch)),
      );
    });

    test('checks the account before the version', () async {
      final created = okValue(await _create(repository));
      await (db.update(db.transactionsTable)..where((t) => t.id.equals(created.id))).write(const TransactionsTableCompanion(version: Value(2)));
      await _softDeleteAccount(db, 'acc-cash');

      expect(await repository.updateTransaction(created), _refusedBy(const GPNotFoundFailure()));
    });
  });

  group('deleteTransaction', () {
    test('soft-deletes: the row stays, stamped, and leaves the list', () async {
      final created = okValue(await _create(repository));
      clock.advance(const Duration(minutes: 1));

      expect(await repository.deleteTransaction(created.id), const GPOk<void>(null));

      final stored = (await _storedRows(db)).single;
      expect(stored.deletedAt, clock.nowEpochMillis());
      expect((await repository.watchTransactions(TransactionQuery(limit: 50)).first).transactions, isEmpty);
    });

    test('reports not found the second time, and for an unknown id', () async {
      final created = okValue(await _create(repository));
      await repository.deleteTransaction(created.id);

      expect(await repository.deleteTransaction(created.id), const GPErr<void>(GPNotFoundFailure()));
      expect(await repository.deleteTransaction('tx-missing'), const GPErr<void>(GPNotFoundFailure()));
    });

    test('deletes even when the account is already gone — the only way to clean one up', () async {
      final created = okValue(await _create(repository));
      await _softDeleteAccount(db, 'acc-cash');

      expect(await repository.deleteTransaction(created.id), const GPOk<void>(null));
    });
  });

  group('restoreTransaction', () {
    test('brings a deleted transaction back into the list, stamped', () async {
      final created = okValue(await _create(repository));
      await repository.deleteTransaction(created.id);
      clock.advance(const Duration(seconds: 3));

      expect(await repository.restoreTransaction(created.id), const GPOk<void>(null));

      final stored = (await _storedRows(db)).single;
      expect(stored.deletedAt, isNull);
      expect(stored.updatedAt, clock.nowEpochMillis());
      expect((await repository.watchTransactions(TransactionQuery(limit: 50)).first).transactions.single.id, created.id);
    });

    test('reports not found for a live transaction, an unknown id, and one of another owner', () async {
      final created = okValue(await _create(repository));
      final theirs = TransactionRepositoryImpl(clock: clock, dao: dao, logger: logger, uuidGenerator: FakeUuidGenerator('theirs'), ownerId: _otherOwner);
      final their = okValue(await theirs.createTransaction(amount: Money(1000, 'VND'), type: TransactionType.expense, occurredAt: _occurredAt, accountId: 'acc-theirs'));
      await theirs.deleteTransaction(their.id);

      expect(await repository.restoreTransaction(created.id), const GPErr<void>(GPNotFoundFailure()));
      expect(await repository.restoreTransaction('tx-missing'), const GPErr<void>(GPNotFoundFailure()));
      expect(await repository.restoreTransaction(their.id), const GPErr<void>(GPNotFoundFailure()));
    });

    test('is refused once its account is deleted, and the transaction stays deleted', () async {
      final created = okValue(await _create(repository));
      await repository.deleteTransaction(created.id);
      await _softDeleteAccount(db, 'acc-cash');

      expect(await repository.restoreTransaction(created.id), const GPErr<void>(GPNotFoundFailure()));
      expect((await _storedRows(db)).single.deletedAt, isNotNull);
    });

    test("is refused once a transfer's destination is deleted", () async {
      final created = okValue(await _create(repository, type: TransactionType.transfer, categoryId: null, destinationAccountId: 'acc-bank'));
      await repository.deleteTransaction(created.id);
      await _softDeleteAccount(db, 'acc-bank');

      expect(await repository.restoreTransaction(created.id), const GPErr<void>(GPNotFoundFailure()));
    });

    test('an archived account still takes it back: archived counts as live', () async {
      final created = okValue(await _create(repository, accountId: 'acc-archived'));
      await repository.deleteTransaction(created.id);

      expect(await repository.restoreTransaction(created.id), const GPOk<void>(null));
    });
  });

  group('watchAccountBalances', () {
    test('pairs each account with its balance, in the currency of that account', () async {
      okValue(await _create(repository, amount: Money(45000, 'VND')));
      okValue(await _create(repository, amount: Money(1250, 'USD'), accountId: 'acc-usd', categoryId: null));

      final balances = await repository.watchAccountBalances().first;
      final byId = {for (final balance in balances) balance.account.id: balance.balance};

      expect(byId['acc-cash'], Money(-45000, 'VND'));
      expect(byId['acc-usd'], Money(-1250, 'USD'));
      expect(byId.containsKey('acc-archived'), isFalse);
      expect(byId.containsKey('acc-theirs'), isFalse);
    });

    test('an account row that will not map fails the list, logged by id and reason only', () async {
      await (db.update(db.accountsTable)..where((a) => a.id.equals('acc-bank'))).write(const AccountsTableCompanion(type: Value('savings')));

      await expectLater(repository.watchAccountBalances(), emitsError(const GPDatabaseFailure()));
      expect(logger.last.fields, {'entity': 'account', 'id': 'acc-bank', 'reason': 'unknownType'});
    });
  });

  group('hasLiveTransactions', () {
    test('answers yes for either side of a transfer, and no for an account nothing touches', () async {
      okValue(await _create(repository, type: TransactionType.transfer, categoryId: null, destinationAccountId: 'acc-bank'));

      expect(await repository.hasLiveTransactions('acc-cash'), const GPOk<bool>(true));
      expect(await repository.hasLiveTransactions('acc-bank'), const GPOk<bool>(true));
      expect(await repository.hasLiveTransactions('acc-usd'), const GPOk<bool>(false));
    });

    test('stops counting a transaction once it is deleted', () async {
      final created = okValue(await _create(repository));
      await repository.deleteTransaction(created.id);

      expect(await repository.hasLiveTransactions('acc-cash'), const GPOk<bool>(false));
    });
  });

  group('watchTransactions', () {
    test('emits a snapshot of the window, newest first, and re-emits when a transaction is created', () async {
      final emissions = <TransactionListSnapshot>[];
      final subscription = repository.watchTransactions(TransactionQuery(limit: 50)).listen(emissions.add);

      await pumpEventQueue();
      okValue(await _create(repository, at: _occurredAt));
      await pumpEventQueue();
      okValue(await _create(repository, at: _occurredAt.add(const Duration(hours: 1))));
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions.map((s) => s.transactions.map((t) => t.id).toList()), [
        <String>[],
        ['id-v7-1'],
        ['id-v7-2', 'id-v7-1'],
      ]);
      expect(emissions.last.unreadableCount, 0);
      expect(emissions.last.hasMore, isFalse);
    });

    test('passes the query down: types as storage values, the range as millis, accounts on either side', () async {
      okValue(await _create(repository, at: DateTime.utc(2026, 9))); // id-v7-1 — expense on cash, on `from` exactly: included
      okValue(await _create(repository, type: TransactionType.transfer, at: DateTime.utc(2026, 9, 2), accountId: 'acc-bank', destinationAccountId: 'acc-cash')); // id-v7-2
      okValue(await _create(repository, type: TransactionType.income, at: DateTime.utc(2026, 9, 3))); // id-v7-3 — an income: filtered out by type
      okValue(await _create(repository, at: DateTime.utc(2026, 10))); // id-v7-4 — on `to` exactly: excluded
      okValue(await _create(repository, at: DateTime.utc(2026, 9, 4), accountId: 'acc-bank')); // id-v7-5 — bank only: filtered out by account

      final snapshot = await repository
          .watchTransactions(
            TransactionQuery(
              accountIds: const {'acc-cash'},
              types: const {TransactionType.expense, TransactionType.transfer},
              from: DateTime.utc(2026, 9),
              to: DateTime.utc(2026, 10),
              limit: 50,
            ),
          )
          .first;

      expect(snapshot.transactions.map((t) => t.id), ['id-v7-2', 'id-v7-1']);
    });

    test('says there may be more exactly when the window came back full', () async {
      for (var i = 0; i < 3; i++) {
        okValue(await _create(repository, at: _occurredAt.add(Duration(minutes: i))));
      }

      final windowOfTwo = await repository.watchTransactions(TransactionQuery(limit: 2)).first;
      expect(windowOfTwo.hasMore, isTrue);
      expect(windowOfTwo.transactions, hasLength(2));
      // Exactly full looks the same as "more behind it" — one larger window settles it (ADR-0011).
      expect((await repository.watchTransactions(TransactionQuery(limit: 3)).first).hasMore, isTrue);
      expect((await repository.watchTransactions(TransactionQuery(limit: 4)).first).hasMore, isFalse);
    });

    test('counts an unreadable row instead of failing the list — and hasMore counts it too', () async {
      okValue(await _create(repository, at: DateTime.utc(2026, 9, 28)));
      await _insertUnreadableRow(db, 'tx-bad');

      final snapshot = await repository.watchTransactions(TransactionQuery(limit: 2)).first;

      expect(snapshot.transactions.map((t) => t.id), ['id-v7-1']);
      expect(snapshot.unreadableCount, 1);
      // 1 mapped + 1 unreadable fill the window of two; counting the mapped row alone would make it look short.
      expect(snapshot.hasMore, isTrue);
    });

    test('logs an unreadable row once per stream, however often the list re-emits', () async {
      await _insertUnreadableRow(db, 'tx-bad');

      final emissions = <TransactionListSnapshot>[];
      final subscription = repository.watchTransactions(TransactionQuery(limit: 50)).listen(emissions.add);

      await pumpEventQueue();
      okValue(await _create(repository));
      await pumpEventQueue();
      okValue(await _create(repository));
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions, hasLength(3));
      expect(emissions.every((s) => s.unreadableCount == 1), isTrue);

      final rejected = logger.records.where((r) => r.message == 'transaction row could not be mapped').toList();
      expect(rejected, hasLength(1));
      expect(rejected.single.fields, {'entity': 'transaction', 'id': 'tx-bad', 'reason': 'unknownType'});
    });
  });

  group('watchTransaction', () {
    test('emits the transaction, then null once it is deleted', () async {
      final created = okValue(await _create(repository));

      final emissions = <String?>[];
      final subscription = repository.watchTransaction(created.id).listen((t) => emissions.add(t?.id));

      await pumpEventQueue();
      await repository.deleteTransaction(created.id);
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions, [created.id, null]);
    });

    test('puts an unreadable row on the error channel as a GPDatabaseFailure — one row has no partial answer', () async {
      await _insertUnreadableRow(db, 'tx-bad');

      await expectLater(repository.watchTransaction('tx-bad'), emitsError(const GPDatabaseFailure()));
      expect(logger.last.fields, {'entity': 'transaction', 'id': 'tx-bad', 'reason': 'unknownType'});
    });
  });

  group('a write the database refuses', () {
    test('createTransaction reports it and logs an id, not the row', () async {
      final result = await _repositoryOver(_ThrowingTransactionDao(db, Exception('disk full')), clock: clock, logger: logger, uuid: uuid).createTransaction(
        amount: Money(125000, 'VND'),
        type: TransactionType.expense,
        occurredAt: _occurredAt,
        accountId: 'acc-cash',
        note: 'Phở bò',
      );

      expect(result, _refusedBy(const GPDatabaseFailure()));
      expect(logger.last.level, GPLogLevel.error);
      expect(logger.last.fields, {'entity': 'transaction', 'id': 'id-v7-1'});
    });

    test('updateTransaction reports it, rolling the transaction back', () async {
      final created = okValue(await _create(repository));

      final result = await _repositoryOver(
        _ThrowingTransactionDao(db, Exception('locked')),
        clock: clock,
        logger: logger,
        uuid: uuid,
      ).updateTransaction(okValue(created.update(note: 'Bún chả')));

      expect(result, _refusedBy(const GPDatabaseFailure()));
      expect((await _storedRows(db)).single.note, isNull);
    });

    test('deleteTransaction reports it too', () async {
      expect(
        await _repositoryOver(_ThrowingTransactionDao(db, Exception('io error')), clock: clock, logger: logger, uuid: uuid).deleteTransaction('tx-1'),
        const GPErr<void>(GPDatabaseFailure()),
      );
      expect(logger.last.fields, {'entity': 'transaction', 'id': 'tx-1'});
    });

    test('restoreTransaction reports it too, and the transaction stays deleted', () async {
      final created = okValue(await _create(repository));
      await repository.deleteTransaction(created.id);

      expect(
        await _repositoryOver(_ThrowingTransactionDao(db, Exception('io error')), clock: clock, logger: logger, uuid: uuid).restoreTransaction(created.id),
        const GPErr<void>(GPDatabaseFailure()),
      );
      expect(logger.last.fields, {'entity': 'transaction', 'id': created.id});
      expect((await _storedRows(db)).single.deletedAt, isNotNull);
    });

    test('an Error is not swallowed — it is a bug and must reach the crash reporter', () async {
      await expectLater(
        _repositoryOver(_ThrowingTransactionDao(db, StateError('broken invariant')), clock: clock, logger: logger, uuid: uuid).createTransaction(
          amount: Money(125000, 'VND'),
          type: TransactionType.expense,
          occurredAt: _occurredAt,
          accountId: 'acc-cash',
        ),
        throwsA(isA<StateError>()),
      );
      expect(logger.records, isEmpty);
    });
  });

  group('the delete check the database refuses', () {
    test('comes back as a GPDatabaseFailure, logged against the account it was asked about', () async {
      final failing = _repositoryOver(_ThrowingTransactionDao(db, Exception('disk I/O')), clock: clock, logger: logger, uuid: uuid);

      expect(await failing.hasLiveTransactions('acc-cash'), const GPErr<bool>(GPDatabaseFailure()));
      expect(logger.last.fields, {'entity': 'account', 'id': 'acc-cash'});
    });
  });

  group('a read the database refuses', () {
    test('a query SQLite refuses reaches the caller as a GPDatabaseFailure, not as a raw SqliteException', () async {
      // No double: a dropped table fails the real query the way a corrupt file would.
      await db.customStatement('DROP TABLE transactions');

      await expectLater(repository.watchTransactions(TransactionQuery(limit: 50)), emitsError(const GPDatabaseFailure()));
      expect(logger.last.error, isA<SqliteException>());
    });

    test('watchTransactions reports an exception and logs an entity type, nothing else', () async {
      await expectLater(
        _repositoryOver(
          _FailingStreamTransactionDao(db, SqliteException(10, 'disk I/O error')),
          clock: clock,
          logger: logger,
          uuid: uuid,
        ).watchTransactions(TransactionQuery(limit: 50)),
        emitsError(const GPDatabaseFailure()),
      );

      expect(logger.last.fields, {'entity': 'transaction'});
    });

    test('watchAccountBalances reports it too, logged against accounts', () async {
      await expectLater(
        _repositoryOver(_FailingStreamTransactionDao(db, SqliteException(10, 'disk I/O error')), clock: clock, logger: logger, uuid: uuid).watchAccountBalances(),
        emitsError(const GPDatabaseFailure()),
      );

      expect(logger.last.fields, {'entity': 'account'});
    });

    test('watchTransaction reports it too, and logs the id', () async {
      await expectLater(
        _repositoryOver(_FailingStreamTransactionDao(db, SqliteException(10, 'disk I/O error')), clock: clock, logger: logger, uuid: uuid).watchTransaction('tx-1'),
        emitsError(const GPDatabaseFailure()),
      );

      expect(logger.last.fields, {'entity': 'transaction', 'id': 'tx-1'});
    });

    test('an Error is forwarded unchanged', () async {
      final bug = StateError('broken invariant');
      final failing = _repositoryOver(_FailingStreamTransactionDao(db, bug), clock: clock, logger: logger, uuid: uuid);

      await expectLater(failing.watchTransactions(TransactionQuery(limit: 50)), emitsError(same(bug)));
      await expectLater(failing.watchTransaction('tx-1'), emitsError(same(bug)));
      expect(logger.records, isEmpty);
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
        createdAt: 0,
        updatedAt: 0,
        version: 1,
      ),
    );

TransactionRepositoryImpl _repositoryOver(TransactionDao dao, {required FakeClock clock, required RecordingLogger logger, required FakeUuidGenerator uuid}) =>
    TransactionRepositoryImpl(clock: clock, dao: dao, logger: logger, uuidGenerator: uuid, ownerId: localOwnerId);

Future<GPResult<TransactionEntity>> _create(
  TransactionRepositoryImpl repository, {
  Money? amount,
  TransactionType type = TransactionType.expense,
  DateTime? at,
  String accountId = 'acc-cash',
  String? categoryId = 'cat-food',
  String? destinationAccountId,
  String? note,
}) => repository.createTransaction(
  amount: amount ?? Money(125000, 'VND'),
  type: type,
  occurredAt: at ?? _occurredAt,
  accountId: accountId,
  categoryId: categoryId,
  destinationAccountId: destinationAccountId,
  note: note,
);

GPErr<TransactionEntity> _refusedBy(GPFailure failure) => GPErr(failure);

Future<List<TransactionRow>> _storedRows(GPAppDatabase db) => db.select(db.transactionsTable).get();

Future<void> _softDeleteAccount(GPAppDatabase db, String id) =>
    (db.update(db.accountsTable)..where((t) => t.id.equals(id))).write(const AccountsTableCompanion(deletedAt: Value(1)));

/// A `refund` row: the mapper refuses it, the table accepts it (no vocabulary CHECK, ADR-0009).
Future<void> _insertUnreadableRow(GPAppDatabase db, String id) => db
    .into(db.transactionsTable)
    .insert(
      TransactionsTableCompanion.insert(
        id: id,
        ownerId: localOwnerId,
        type: 'refund',
        accountId: 'acc-cash',
        amountMinor: 1,
        currencyCode: 'VND',
        occurredAt: 1,
        createdAt: 0,
        updatedAt: 0,
        version: 1,
        syncStatus: 'pending',
      ),
    );

/// A real database does not fail on request, so the `catch` sites are reached through a DAO that throws; its reads stay real.
final class _ThrowingTransactionDao extends TransactionDao {
  _ThrowingTransactionDao(super.attachedDatabase, this._thrown);

  final Object _thrown;

  @override
  Future<void> insertTransaction(TransactionsTableCompanion row) => Future.error(_thrown);

  @override
  Future<int> updateTransaction(String id, {required TransactionsTableCompanion patch, required int baseVersion, required int now}) => Future.error(_thrown);

  @override
  Future<int> softDelete(String id, {required int now}) => Future.error(_thrown);

  @override
  Future<int> restore(String id, {required int now}) => Future.error(_thrown);

  @override
  Future<bool> hasLiveTransactions({required String accountId, required String ownerId}) => Future.error(_thrown);
}

final class _FailingStreamTransactionDao extends TransactionDao {
  _FailingStreamTransactionDao(super.attachedDatabase, this._error);

  final Object _error;

  @override
  Stream<List<TransactionRow>> watchTransactions(
    String ownerId, {
    Set<String>? accountIds,
    Set<String>? categoryIds,
    Set<String>? types,
    int? fromMillis,
    required int limit,
    int? toMillis,
  }) => Stream.error(_error);

  @override
  Stream<TransactionRow?> watchTransaction({required String id, required String ownerId}) => Stream.error(_error);

  @override
  Stream<List<({AccountRow account, int balanceMinor})>> watchAccountBalances(String ownerId) => Stream.error(_error);
}
