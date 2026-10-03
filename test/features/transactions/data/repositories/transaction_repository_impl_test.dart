// `isNull`/`isNotNull` are both drift SQL predicates and matchers; this file wants the matchers.
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

/// `TransactionRepositoryImpl` (W4 T6), on a real in-memory database with the real DAO — the stance `account_repository_impl_test.dart` explains: what is
/// worth asserting is what a user would notice, and that needs real SQL. The clock and the id generator are fakes because they are the two sources of
/// nondeterminism the assertions have to name.
///
/// What is specific to this repository: the two account rules that run inside the write's transaction (ADR-0010), and a list that counts a bad row
/// instead of failing (ADR-0011).
void main() {
  late GPAppDatabase db;
  late TransactionDao dao;
  late FakeClock clock;
  late FakeUuidGenerator uuid;
  late RecordingLogger logger;
  late TransactionRepositoryImpl repository;

  final startedAt = DateTime.utc(2026, 9, 28, 9);
  final occurredAt = DateTime.utc(2026, 9, 28, 5, 30);
  const otherOwner = 'someone-else';

  setUp(() async {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    dao = TransactionDao(db);
    clock = FakeClock(startedAt);
    uuid = FakeUuidGenerator();
    logger = RecordingLogger(clock: clock);
    repository = TransactionRepositoryImpl(dao: dao, clock: clock, uuidGenerator: uuid, logger: logger, ownerId: localOwnerId);

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
            createdAt: 0,
            updatedAt: 0,
            version: 1,
          ),
        );

    await account('acc-cash');
    await account('acc-bank');
    await account('acc-usd', currencyCode: 'USD');
    await account('acc-archived', isArchived: true);
    await account('acc-theirs', ownerId: otherOwner);
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

  tearDown(() async {
    await db.close();
  });

  Future<GPResult<TransactionEntity>> create({
    TransactionType type = TransactionType.expense,
    String accountId = 'acc-cash',
    String? destinationAccountId,
    String? categoryId = 'cat-food',
    Money? amount,
    DateTime? at,
    String? note,
  }) => repository.createTransaction(
    type: type,
    accountId: accountId,
    destinationAccountId: destinationAccountId,
    categoryId: categoryId,
    amount: amount ?? Money(125000, 'VND'),
    occurredAt: at ?? occurredAt,
    note: note,
  );

  TransactionEntity ok(GPResult<TransactionEntity> result) => (result as GPOk<TransactionEntity>).value;

  GPErr<TransactionEntity> refusedBy(GPFailure failure) => GPErr<TransactionEntity>(failure);

  Future<List<TransactionRow>> storedRows() => db.select(db.transactionsTable).get();

  Future<void> softDeleteAccount(String id) => (db.update(db.accountsTable)..where((t) => t.id.equals(id))).write(const AccountsTableCompanion(deletedAt: Value(1)));

  /// A row the mapper refuses — a `refund`, a type from a newer build — written straight through drift, which the table allows: it has no vocabulary
  /// CHECK (ADR-0009).
  Future<void> insertUnreadableRow(String id, {int occurredAtMillis = 1}) => db
      .into(db.transactionsTable)
      .insert(
        TransactionsTableCompanion.insert(
          id: id,
          ownerId: localOwnerId,
          type: 'refund',
          accountId: 'acc-cash',
          amountMinor: 1,
          currencyCode: 'VND',
          occurredAt: occurredAtMillis,
          createdAt: 0,
          updatedAt: 0,
          version: 1,
          syncStatus: 'pending',
        ),
      );

  group('createTransaction', () {
    test('writes the transaction and returns it as stored — id minted, both timestamps from the clock', () async {
      final created = ok(await create(note: 'Phở bò'));

      expect(created.id, 'id-v7-1');
      expect(created.createdAt, startedAt);
      expect(created.updatedAt, startedAt);
      expect(created.version, 1);

      final stored = (await storedRows()).single;
      expect(stored.id, created.id);
      // The owner the repository was built with — the domain never sees one (the reasoning of `AccountRepository`).
      expect(stored.ownerId, localOwnerId);
      expect(stored.amountMinor, 125000);
      expect(stored.currencyCode, 'VND');
      expect(stored.occurredAt, occurredAt.millisecondsSinceEpoch);
      expect(stored.note, 'Phở bò');
      expect(stored.syncStatus, 'pending');
    });

    test('an entity rule refuses before the database is touched', () async {
      expect(await create(amount: Money.zero('VND')), refusedBy(const GPValidationFailure(GPValidationCode.transactionAmountNotPositive)));
      expect(await create(type: TransactionType.transfer), refusedBy(const GPValidationFailure(GPValidationCode.transactionDestinationMissing)));
      expect(await storedRows(), isEmpty);
    });

    test('refuses an account that is missing, deleted, or not the owner’s — as not found', () async {
      await softDeleteAccount('acc-bank');

      expect(await create(accountId: 'acc-missing'), refusedBy(const GPNotFoundFailure()));
      expect(await create(accountId: 'acc-bank'), refusedBy(const GPNotFoundFailure()));
      // The foreign key alone would have accepted this one: the row exists. ADR-0010's rule is that the account is the owner's.
      expect(await create(accountId: 'acc-theirs'), refusedBy(const GPNotFoundFailure()));
      expect(await storedRows(), isEmpty);
    });

    test('accepts an archived account', () async {
      // Archived is out of the picker, not out of the ledger (ADR-0010).
      expect(await create(accountId: 'acc-archived'), isA<GPOk<TransactionEntity>>());
    });

    test('refuses an amount in another currency than the account’s', () async {
      // The balance is a SQL `SUM`; storing this would add 1234 cents to a dong balance as 1234 dong.
      expect(await create(amount: Money(1234, 'USD')), refusedBy(const GPValidationFailure(GPValidationCode.transactionCurrencyMismatch)));
      expect(await storedRows(), isEmpty);
    });

    test('refuses a transfer into a deleted account, and one between two currencies', () async {
      await softDeleteAccount('acc-bank');

      expect(await create(type: TransactionType.transfer, destinationAccountId: 'acc-bank'), refusedBy(const GPNotFoundFailure()));
      expect(
        await create(type: TransactionType.transfer, destinationAccountId: 'acc-usd'),
        refusedBy(const GPValidationFailure(GPValidationCode.transactionTransferCurrenciesDiffer)),
      );
      expect(await storedRows(), isEmpty);
    });

    test('writes a transfer between two live accounts of one currency', () async {
      // `create` passes `cat-food` by default — a transfer given a category, as a form switched from expense would send it.
      final created = ok(await create(type: TransactionType.transfer, destinationAccountId: 'acc-bank'));

      final stored = (await storedRows()).single;
      expect(stored.destinationAccountId, 'acc-bank');
      // Dropped by the entity, so the table's CHECK never had to refuse it.
      expect(stored.categoryId, isNull);
      expect(created.categoryId, isNull);
    });

    test('a category that does not exist is a database failure — the foreign key refuses it', () async {
      // Whether a category that does exist is live and of the right kind is the use cases' rule (ADR-0010); a dangling id never gets that far.
      expect(await create(categoryId: 'cat-ghost'), refusedBy(const GPDatabaseFailure()));
      expect(logger.last.fields, {'entity': 'transaction', 'id': 'id-v7-1'});
    });
  });

  group('updateTransaction', () {
    test('applies the edit, stamps updated_at from the clock, and leaves version alone', () async {
      final created = ok(await create());
      clock.advance(const Duration(minutes: 5));

      final updated = ok(await repository.updateTransaction(ok(created.update(amount: Money(95000, 'VND'), note: 'Bún chả'))));

      expect(updated.updatedAt, startedAt.add(const Duration(minutes: 5)));
      final stored = (await storedRows()).single;
      expect(stored.amountMinor, 95000);
      expect(stored.note, 'Bún chả');
      expect(stored.updatedAt, updated.updatedAt.millisecondsSinceEpoch);
      // The server's number (§7); an edit never moves it.
      expect(stored.version, 1);
      expect(stored.syncStatus, 'pending');
    });

    test('switches an expense to a transfer in storage, clearing its category', () async {
      final created = ok(await create());

      await repository.updateTransaction(ok(created.update(type: TransactionType.transfer, destinationAccountId: 'acc-bank')));

      final stored = (await storedRows()).single;
      expect(stored.type, 'transfer');
      expect(stored.destinationAccountId, 'acc-bank');
      expect(stored.categoryId, isNull);
    });

    test('reports a conflict with the version that is actually stored', () async {
      final created = ok(await create());
      // Another device's edit, as the pull of W14 will apply it.
      await (db.update(db.transactionsTable)..where((t) => t.id.equals(created.id))).write(const TransactionsTableCompanion(version: Value(2)));

      final result = await repository.updateTransaction(ok(created.update(note: 'Bún chả')));

      expect(result, refusedBy(GPConflictFailure(entityId: created.id, localVersion: 1, remoteVersion: 2)));
      expect((await storedRows()).single.note, isNull);
    });

    test('reports a deleted transaction as not found, not as a conflict', () async {
      final created = ok(await create());
      await dao.softDelete(created.id, now: 1);

      expect(await repository.updateTransaction(created), refusedBy(const GPNotFoundFailure()));
    });

    test('refuses when the account was deleted after the form opened', () async {
      final created = ok(await create());
      await softDeleteAccount('acc-cash');

      expect(await repository.updateTransaction(ok(created.update(note: 'Bún chả'))), refusedBy(const GPNotFoundFailure()));
      expect((await storedRows()).single.note, isNull);
    });

    test('refuses when the account’s currency changed after the form opened', () async {
      // The reachable-by-a-correct-user case ADR-0010 names — until an account's currency is frozen, another device can change it.
      final created = ok(await create());
      await (db.update(db.accountsTable)..where((t) => t.id.equals('acc-cash'))).write(const AccountsTableCompanion(currencyCode: Value('USD')));

      expect(
        await repository.updateTransaction(ok(created.update(note: 'Bún chả'))),
        refusedBy(const GPValidationFailure(GPValidationCode.transactionCurrencyMismatch)),
      );
    });

    test('checks the account before the version', () async {
      // Both are wrong at once. The account rule answers first, so nothing is written that should not be (the order ADR-0010 settles at W4 T6).
      final created = ok(await create());
      await (db.update(db.transactionsTable)..where((t) => t.id.equals(created.id))).write(const TransactionsTableCompanion(version: Value(2)));
      await softDeleteAccount('acc-cash');

      expect(await repository.updateTransaction(created), refusedBy(const GPNotFoundFailure()));
    });
  });

  group('deleteTransaction', () {
    test('soft-deletes: the row stays, stamped, and leaves the list', () async {
      final created = ok(await create());
      clock.advance(const Duration(minutes: 1));

      expect(await repository.deleteTransaction(created.id), const GPOk<void>(null));

      final stored = (await storedRows()).single;
      expect(stored.deletedAt, clock.nowEpochMillis());
      expect((await repository.watchTransactions(TransactionQuery(limit: 50)).first).transactions, isEmpty);
    });

    test('reports not found the second time, and for an unknown id', () async {
      final created = ok(await create());
      await repository.deleteTransaction(created.id);

      expect(await repository.deleteTransaction(created.id), const GPErr<void>(GPNotFoundFailure()));
      expect(await repository.deleteTransaction('tx-missing'), const GPErr<void>(GPNotFoundFailure()));
    });

    test('deletes even when the account is already gone — the only way to clean one up', () async {
      final created = ok(await create());
      await softDeleteAccount('acc-cash');

      expect(await repository.deleteTransaction(created.id), const GPOk<void>(null));
    });
  });

  group('hasLiveTransactions', () {
    test('answers yes for either side of a transfer, and no for an account nothing touches', () async {
      ok(await create(type: TransactionType.transfer, destinationAccountId: 'acc-bank', categoryId: null));

      expect(await repository.hasLiveTransactions('acc-cash'), const GPOk<bool>(true));
      // The destination is the side a delete would strand without a word: its balance moves, and nothing lists the account it came from.
      expect(await repository.hasLiveTransactions('acc-bank'), const GPOk<bool>(true));
      expect(await repository.hasLiveTransactions('acc-usd'), const GPOk<bool>(false));
    });

    test('stops counting a transaction once it is deleted', () async {
      final created = ok(await create());
      await repository.deleteTransaction(created.id);

      expect(await repository.hasLiveTransactions('acc-cash'), const GPOk<bool>(false));
    });
  });

  group('watchTransactions', () {
    test('emits a snapshot of the window, newest first, and re-emits when a transaction is created', () async {
      final emissions = <TransactionListSnapshot>[];
      final subscription = repository.watchTransactions(TransactionQuery(limit: 50)).listen(emissions.add);

      await pumpEventQueue();
      ok(await create(at: occurredAt));
      await pumpEventQueue();
      ok(await create(at: occurredAt.add(const Duration(hours: 1))));
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
      ok(await create(at: DateTime.utc(2026, 9))); // id-v7-1 — expense on cash, on `from` exactly: included
      ok(await create(type: TransactionType.transfer, accountId: 'acc-bank', destinationAccountId: 'acc-cash', at: DateTime.utc(2026, 9, 2))); // id-v7-2
      ok(await create(type: TransactionType.income, at: DateTime.utc(2026, 9, 3))); // id-v7-3 — an income: filtered out by type
      ok(await create(at: DateTime.utc(2026, 10))); // id-v7-4 — on `to` exactly: excluded
      ok(await create(accountId: 'acc-bank', at: DateTime.utc(2026, 9, 4))); // id-v7-5 — bank only: filtered out by account

      final snapshot = await repository
          .watchTransactions(
            TransactionQuery(
              limit: 50,
              accountIds: const {'acc-cash'},
              types: const {TransactionType.expense, TransactionType.transfer},
              from: DateTime.utc(2026, 9),
              to: DateTime.utc(2026, 10),
            ),
          )
          .first;

      expect(snapshot.transactions.map((t) => t.id), ['id-v7-2', 'id-v7-1']);
    });

    test('says there may be more exactly when the window came back full', () async {
      for (var i = 0; i < 3; i++) {
        ok(await create(at: occurredAt.add(Duration(minutes: i))));
      }

      Future<TransactionListSnapshot> window(int limit) => repository.watchTransactions(TransactionQuery(limit: limit)).first;

      expect((await window(2)).hasMore, isTrue);
      expect((await window(2)).transactions, hasLength(2));
      // Exactly full looks the same as "more behind it" — one larger window settles it (ADR-0011).
      expect((await window(3)).hasMore, isTrue);
      expect((await window(4)).hasMore, isFalse);
    });

    test('counts an unreadable row instead of failing the list — and hasMore counts it too', () async {
      ok(await create(at: DateTime.utc(2026, 9, 28)));
      await insertUnreadableRow('tx-bad');

      final snapshot = await repository.watchTransactions(TransactionQuery(limit: 2)).first;

      expect(snapshot.transactions.map((t) => t.id), ['id-v7-1']);
      expect(snapshot.unreadableCount, 1);
      // Two rows came back for a window of two. Counting only the mapped one would make a full window look short, and the list would stop loading.
      expect(snapshot.hasMore, isTrue);
    });

    test('logs an unreadable row once per stream, however often the list re-emits', () async {
      await insertUnreadableRow('tx-bad');

      final emissions = <TransactionListSnapshot>[];
      final subscription = repository.watchTransactions(TransactionQuery(limit: 50)).listen(emissions.add);

      await pumpEventQueue();
      ok(await create());
      await pumpEventQueue();
      ok(await create());
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions, hasLength(3));
      expect(emissions.every((s) => s.unreadableCount == 1), isTrue);

      final rejected = logger.records.where((r) => r.message == 'transaction row could not be mapped').toList();
      expect(rejected, hasLength(1));
      // Golden rule 9: an id, an entity type, a reason. The row's amount and note are in scope and neither is here.
      expect(rejected.single.fields, {'entity': 'transaction', 'id': 'tx-bad', 'reason': 'unknownType'});
    });
  });

  group('watchTransaction', () {
    test('emits the transaction, then null once it is deleted', () async {
      final created = ok(await create());

      final emissions = <String?>[];
      final subscription = repository.watchTransaction(created.id).listen((t) => emissions.add(t?.id));

      await pumpEventQueue();
      await repository.deleteTransaction(created.id);
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions, [created.id, null]);
    });

    test('puts an unreadable row on the error channel as a GPDatabaseFailure — one row has no partial answer', () async {
      await insertUnreadableRow('tx-bad');

      await expectLater(repository.watchTransaction('tx-bad'), emitsError(const GPDatabaseFailure()));
      expect(logger.last.fields, {'entity': 'transaction', 'id': 'tx-bad', 'reason': 'unknownType'});
    });
  });

  group('a write the database refuses', () {
    /// A DAO whose writes fail on request — the double `account_repository_impl_test.dart` uses, for the reason it gives: real SQL does not fail when
    /// asked, and the `catch` sites would otherwise be unreachable. Its reads stay real, so the account rules still run first.
    TransactionRepositoryImpl repositoryFailingWith(Object thrown) =>
        TransactionRepositoryImpl(dao: ThrowingTransactionDao(db, thrown), clock: clock, uuidGenerator: uuid, logger: logger, ownerId: localOwnerId);

    test('createTransaction reports it and logs an id, not the row', () async {
      final result = await repositoryFailingWith(Exception('disk full')).createTransaction(
        type: TransactionType.expense,
        accountId: 'acc-cash',
        amount: Money(125000, 'VND'),
        occurredAt: occurredAt,
        note: 'Phở bò',
      );

      expect(result, refusedBy(const GPDatabaseFailure()));
      expect(logger.last.level, GPLogLevel.error);
      // The amount and the note are both in scope at the call site; the log holds neither.
      expect(logger.last.fields, {'entity': 'transaction', 'id': 'id-v7-1'});
    });

    test('updateTransaction reports it, rolling the transaction back', () async {
      final created = ok(await create());

      final result = await repositoryFailingWith(Exception('locked')).updateTransaction(ok(created.update(note: 'Bún chả')));

      expect(result, refusedBy(const GPDatabaseFailure()));
      expect((await storedRows()).single.note, isNull);
    });

    test('deleteTransaction reports it too', () async {
      expect(await repositoryFailingWith(Exception('io error')).deleteTransaction('tx-1'), const GPErr<void>(GPDatabaseFailure()));
      expect(logger.last.fields, {'entity': 'transaction', 'id': 'tx-1'});
    });

    test('an Error is not swallowed — it is a bug and must reach the crash reporter', () async {
      await expectLater(
        repositoryFailingWith(StateError('broken invariant')).createTransaction(
          type: TransactionType.expense,
          accountId: 'acc-cash',
          amount: Money(125000, 'VND'),
          occurredAt: occurredAt,
        ),
        throwsA(isA<StateError>()),
      );
      expect(logger.records, isEmpty);
    });
  });

  group('the delete check the database refuses', () {
    test('comes back as a GPDatabaseFailure, logged against the account it was asked about', () async {
      final failing = TransactionRepositoryImpl(dao: ThrowingTransactionDao(db, Exception('disk I/O')), clock: clock, uuidGenerator: uuid, logger: logger, ownerId: localOwnerId);

      expect(await failing.hasLiveTransactions('acc-cash'), const GPErr<bool>(GPDatabaseFailure()));
      expect(logger.last.fields, {'entity': 'account', 'id': 'acc-cash'});
    });
  });

  group('a read the database refuses', () {
    TransactionRepositoryImpl repositoryReadingFrom(Object error) =>
        TransactionRepositoryImpl(dao: FailingStreamTransactionDao(db, error), clock: clock, uuidGenerator: uuid, logger: logger, ownerId: localOwnerId);

    test('a query SQLite refuses reaches the caller as a GPDatabaseFailure, not as a raw SqliteException', () async {
      // No double: a dropped table fails the real query the way a corrupt file would.
      await db.customStatement('DROP TABLE transactions');

      await expectLater(repository.watchTransactions(TransactionQuery(limit: 50)), emitsError(const GPDatabaseFailure()));
      expect(logger.last.error, isA<SqliteException>());
    });

    test('watchTransactions reports an exception and logs an entity type, nothing else', () async {
      await expectLater(repositoryReadingFrom(SqliteException(10, 'disk I/O error')).watchTransactions(TransactionQuery(limit: 50)), emitsError(const GPDatabaseFailure()));

      expect(logger.last.fields, {'entity': 'transaction'});
    });

    test('watchTransaction reports it too, and logs the id', () async {
      await expectLater(repositoryReadingFrom(SqliteException(10, 'disk I/O error')).watchTransaction('tx-1'), emitsError(const GPDatabaseFailure()));

      expect(logger.last.fields, {'entity': 'transaction', 'id': 'tx-1'});
    });

    test('an Error is forwarded unchanged', () async {
      final bug = StateError('broken invariant');
      final failing = repositoryReadingFrom(bug);

      await expectLater(failing.watchTransactions(TransactionQuery(limit: 50)), emitsError(same(bug)));
      await expectLater(failing.watchTransaction('tx-1'), emitsError(same(bug)));
      expect(logger.records, isEmpty);
    });
  });
}

/// A [TransactionDao] whose three writes — and [hasLiveTransactions], the one read that answers with a future — fail with a given object:
/// `ThrowingAccountDao`'s twin. Subclassed rather than faked through an interface, so it stays attached to the same database: `transaction()` and every
/// other read still behave, and only the call under test misbehaves.
class ThrowingTransactionDao extends TransactionDao {
  ThrowingTransactionDao(super.attachedDatabase, this.thrown);

  final Object thrown;

  @override
  Future<void> insertTransaction(TransactionsTableCompanion row) => Future<void>.error(thrown);

  @override
  Future<int> updateTransaction(String id, {required int baseVersion, required TransactionsTableCompanion patch, required int now}) => Future<int>.error(thrown);

  @override
  Future<int> softDelete(String id, {required int now}) => Future<int>.error(thrown);

  @override
  Future<bool> hasLiveTransactions(String ownerId, String accountId) => Future<bool>.error(thrown);
}

/// A [TransactionDao] whose watch streams fail with a given object — `FailingStreamAccountDao`'s twin, and `Stream.error` for the same reason: that is how
/// a watched query's failure really arrives.
class FailingStreamTransactionDao extends TransactionDao {
  FailingStreamTransactionDao(super.attachedDatabase, this.error);

  final Object error;

  @override
  Stream<List<TransactionRow>> watchTransactions(
    String ownerId, {
    required int limit,
    Set<String>? accountIds,
    Set<String>? categoryIds,
    Set<String>? types,
    int? fromMillis,
    int? toMillis,
  }) => Stream<List<TransactionRow>>.error(error);

  @override
  Stream<TransactionRow?> watchTransaction(String ownerId, String id) => Stream<TransactionRow?>.error(error);
}
