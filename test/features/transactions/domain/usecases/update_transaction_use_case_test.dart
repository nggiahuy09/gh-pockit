import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/categories/data/daos/category_dao.dart';
import 'package:ghpockit/features/categories/data/repositories/category_repository_impl.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/usecases/update_transaction_use_case.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/fake_uuid_generator.dart';
import '../../../../helpers/recording_logger.dart';
import '../../../../helpers/results.dart';

const _mismatch = GPErr<TransactionEntity>(GPValidationFailure(GPValidationCode.transactionCategoryTypeMismatch));

/// Real repositories on in-memory SQL: the rule turns on what the stored row and a real `watchCategory` answer.
void main() {
  late GPAppDatabase db;
  late CategoryRepositoryImpl categories;
  late TransactionRepositoryImpl transactions;
  late UpdateTransactionUseCase updateTransaction;

  setUp(() async {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    final clock = FakeClock(DateTime.utc(2026, 9, 30, 9));
    final uuid = FakeUuidGenerator();
    final logger = RecordingLogger(clock);

    categories = CategoryRepositoryImpl(clock: clock, dao: CategoryDao(db), logger: logger, uuidGenerator: uuid, ownerId: localOwnerId);
    transactions = TransactionRepositoryImpl(clock: clock, dao: TransactionDao(db), logger: logger, uuidGenerator: uuid, ownerId: localOwnerId);
    updateTransaction = UpdateTransactionUseCase(categories, transactions);

    for (final id in ['acc-cash', 'acc-bank']) {
      await db
          .into(db.accountsTable)
          .insert(
            AccountsTableCompanion.insert(
              id: id,
              ownerId: localOwnerId,
              name: id,
              type: 'cash',
              currencyCode: 'VND',
              initialBalance: 0,
              isArchived: false,
              createdAt: 0,
              updatedAt: 0,
              version: 1,
            ),
          );
    }

    await _insertCategory(db, 'cat-food');
    await _insertCategory(db, 'cat-rent');
    await _insertCategory(db, 'cat-salary', type: 'income');
    await _insertCategory(db, 'cat-deleted', deletedAt: 1);
  });

  tearDown(() => db.close());

  group('an edit that files the transaction anew', () {
    test('moves it to another category of its kind', () async {
      final transaction = await _filedUnderFood(transactions);

      expect(await _update(transaction.update(categoryId: 'cat-rent'), updateTransaction), isA<GPOk<TransactionEntity>>());
      expect((await _stored(db, transaction.id)).categoryId, 'cat-rent');
    });

    test('refuses a category of the other kind, and the row stays as it was', () async {
      final transaction = await _filedUnderFood(transactions);

      expect(await _update(transaction.update(categoryId: 'cat-salary'), updateTransaction), _mismatch);
      expect((await _stored(db, transaction.id)).categoryId, 'cat-food');
    });

    test('refuses a deleted category, or a missing one, as not found', () async {
      final transaction = await _filedUnderFood(transactions);

      for (final categoryId in const ['cat-deleted', 'cat-missing']) {
        expect(await _update(transaction.update(categoryId: categoryId), updateTransaction), const GPErr<TransactionEntity>(GPNotFoundFailure()), reason: categoryId);
      }
      expect((await _stored(db, transaction.id)).categoryId, 'cat-food');
    });

    test('judges a type change against the category it keeps', () async {
      // Expense → income keeps the category (only a transfer drops it), so `cat-food` is re-filed under an income.
      final transaction = await _filedUnderFood(transactions);

      expect(await _update(transaction.update(type: TransactionType.income), updateTransaction), _mismatch);
      expect(await _update(transaction.update(type: TransactionType.income, categoryId: 'cat-salary'), updateTransaction), isA<GPOk<TransactionEntity>>());
    });
  });

  group('an edit that leaves the filing alone', () {
    test('keeps a category deleted since — the transaction reads as uncategorised and stays editable', () async {
      final transaction = await _filedUnderFood(transactions);
      await categories.deleteCategory('cat-food');

      expect(await _update(transaction.update(note: 'Phở bò'), updateTransaction), isA<GPOk<TransactionEntity>>());
      expect((await _stored(db, transaction.id)).categoryId, 'cat-food');
    });

    test('switches to a transfer without judging the category it drops', () async {
      final transaction = await _filedUnderFood(transactions);
      await categories.deleteCategory('cat-food');

      final result = await _update(transaction.update(type: TransactionType.transfer, destinationAccountId: 'acc-bank'), updateTransaction);

      expect(result, isA<GPOk<TransactionEntity>>());
      expect((await _stored(db, transaction.id)).categoryId, isNull);
    });

    test('clears the category with nothing to judge', () async {
      final transaction = await _filedUnderFood(transactions);

      expect(await _update(transaction.update(clearCategory: true), updateTransaction), isA<GPOk<TransactionEntity>>());
      expect((await _stored(db, transaction.id)).categoryId, isNull);
    });
  });

  group('the stored row', () {
    test('a transaction deleted meanwhile is not found', () async {
      final transaction = await _filedUnderFood(transactions);
      await transactions.deleteTransaction(transaction.id);

      expect(await _update(transaction.update(categoryId: 'cat-rent'), updateTransaction), const GPErr<TransactionEntity>(GPNotFoundFailure()));
    });

    test('a stale edit is reported as a conflict, not judged by its category', () async {
      // A pull wrote version 2; `cat-deleted` would be refused if the category were judged first.
      final transaction = await _filedUnderFood(transactions);
      await (db.update(db.transactionsTable)..where((t) => t.id.equals(transaction.id))).write(const TransactionsTableCompanion(version: Value(2)));

      final result = await _update(transaction.update(categoryId: 'cat-deleted'), updateTransaction);

      expect(result, GPErr<TransactionEntity>(GPConflictFailure(entityId: transaction.id, localVersion: 1, remoteVersion: 2)));
    });

    test('a stored row that cannot be read is a database failure', () async {
      // A `refund` row from a newer build: the mapper refuses it, so the use case cannot read what the edit changes.
      await db
          .into(db.transactionsTable)
          .insert(
            TransactionsTableCompanion.insert(
              id: 'tx-unreadable',
              ownerId: localOwnerId,
              type: 'refund',
              accountId: 'acc-cash',
              categoryId: const Value('cat-food'),
              amountMinor: 1,
              currencyCode: 'VND',
              occurredAt: 0,
              createdAt: 0,
              updatedAt: 0,
              version: 1,
              syncStatus: 'pending',
            ),
          );
      final edit = TransactionEntity.create(
        amount: Money(1, 'VND'),
        type: TransactionType.expense,
        createdAt: DateTime.utc(1970),
        occurredAt: DateTime.utc(1970),
        updatedAt: DateTime.utc(1970),
        accountId: 'acc-cash',
        categoryId: 'cat-food',
        id: 'tx-unreadable',
      );

      expect(await _update(edit, updateTransaction), const GPErr<TransactionEntity>(GPDatabaseFailure()));
    });
  });

  test('the input logs the id and the version, never the amount or the note', () async {
    final transaction = await _filedUnderFood(transactions);

    expect(UpdateTransactionInput(transaction).toLog(), {'transaction_id': transaction.id, 'version': 1});
  });
}

Future<void> _insertCategory(GPAppDatabase db, String id, {String type = 'expense', int? deletedAt}) => db
    .into(db.categoriesTable)
    .insert(
      CategoriesTableCompanion.insert(
        id: id,
        ownerId: localOwnerId,
        name: Value(id),
        type: type,
        isSystem: false,
        createdAt: 0,
        updatedAt: 0,
        version: 1,
        deletedAt: Value(deletedAt),
      ),
    );

/// Through the repository, not a use case, so the setup cannot fail on the rule under test.
Future<TransactionEntity> _filedUnderFood(TransactionRepositoryImpl transactions) async => okValue(
  await transactions.createTransaction(
    amount: Money(125000, 'VND'),
    type: TransactionType.expense,
    occurredAt: DateTime.utc(2026, 9, 30, 5, 30),
    accountId: 'acc-cash',
    categoryId: 'cat-food',
  ),
);

Future<TransactionRow> _stored(GPAppDatabase db, String id) => (db.select(db.transactionsTable)..where((t) => t.id.equals(id))).getSingle();

Future<GPResult<TransactionEntity>> _update(GPResult<TransactionEntity> edit, UpdateTransactionUseCase useCase) => useCase.execute(UpdateTransactionInput(okValue(edit)));
