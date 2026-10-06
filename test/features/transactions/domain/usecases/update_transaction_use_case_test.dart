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
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/usecases/update_transaction_use_case.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/fake_uuid_generator.dart';
import '../../../../helpers/recording_logger.dart';

/// Real repositories on in-memory SQL: the rule turns on what the stored row and a real `watchCategory` answer.
void main() {
  late GPAppDatabase db;
  late TransactionRepositoryImpl transactions;
  late CategoryRepositoryImpl categories;
  late UpdateTransactionUseCase updateTransaction;

  setUp(() async {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    final clock = FakeClock(DateTime.utc(2026, 9, 30, 9));
    final uuid = FakeUuidGenerator();
    final logger = RecordingLogger(clock: clock);

    transactions = TransactionRepositoryImpl(dao: TransactionDao(db), clock: clock, uuidGenerator: uuid, logger: logger, ownerId: localOwnerId);
    categories = CategoryRepositoryImpl(dao: CategoryDao(db), clock: clock, uuidGenerator: uuid, logger: logger, ownerId: localOwnerId);
    updateTransaction = UpdateTransactionUseCase(transactionRepository: transactions, categoryRepository: categories);

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

    Future<void> category(String id, {String type = 'expense', int? deletedAt}) => db
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

    await category('cat-food');
    await category('cat-rent');
    await category('cat-salary', type: 'income');
    await category('cat-deleted', deletedAt: 1);
  });

  tearDown(() async {
    await db.close();
  });

  T ok<T>(GPResult<T> result) => (result as GPOk<T>).value;

  /// Through the repository, not a use case, so the setup cannot fail on the rule under test.
  Future<TransactionEntity> filedUnderFood() async => ok(
    await transactions.createTransaction(
      type: TransactionType.expense,
      accountId: 'acc-cash',
      amount: Money(125000, 'VND'),
      occurredAt: DateTime.utc(2026, 9, 30, 5, 30),
      categoryId: 'cat-food',
    ),
  );

  Future<TransactionRow> stored(String id) => (db.select(db.transactionsTable)..where((t) => t.id.equals(id))).getSingle();

  const mismatch = GPErr<TransactionEntity>(GPValidationFailure(GPValidationCode.transactionCategoryTypeMismatch));

  group('an edit that files the transaction anew', () {
    test('moves it to another category of its kind', () async {
      final transaction = await filedUnderFood();

      expect(await updateTransaction(ok(transaction.update(categoryId: 'cat-rent'))), isA<GPOk<TransactionEntity>>());
      expect((await stored(transaction.id)).categoryId, 'cat-rent');
    });

    test('refuses a category of the other kind, and the row stays as it was', () async {
      final transaction = await filedUnderFood();

      expect(await updateTransaction(ok(transaction.update(categoryId: 'cat-salary'))), mismatch);
      expect((await stored(transaction.id)).categoryId, 'cat-food');
    });

    test('refuses a deleted category, or a missing one, as not found', () async {
      final transaction = await filedUnderFood();

      for (final categoryId in ['cat-deleted', 'cat-missing']) {
        expect(await updateTransaction(ok(transaction.update(categoryId: categoryId))), const GPErr<TransactionEntity>(GPNotFoundFailure()), reason: categoryId);
      }
      expect((await stored(transaction.id)).categoryId, 'cat-food');
    });

    test('judges a type change against the category it keeps', () async {
      // Expense → income keeps the category (only a transfer drops it), so `cat-food` is re-filed under an income.
      final transaction = await filedUnderFood();

      expect(await updateTransaction(ok(transaction.update(type: TransactionType.income))), mismatch);
      expect(await updateTransaction(ok(transaction.update(type: TransactionType.income, categoryId: 'cat-salary'))), isA<GPOk<TransactionEntity>>());
    });
  });

  group('an edit that leaves the filing alone', () {
    test('keeps a category deleted since — the transaction reads as uncategorised and stays editable', () async {
      final transaction = await filedUnderFood();
      await categories.deleteCategory('cat-food');

      final result = await updateTransaction(ok(transaction.update(note: 'Phở bò')));

      expect(result, isA<GPOk<TransactionEntity>>());
      expect((await stored(transaction.id)).categoryId, 'cat-food');
    });

    test('keeps a category whose type was flipped since — the edit did not put it there', () async {
      final transaction = await filedUnderFood();
      final food = (await categories.watchCategory('cat-food').first)!;
      ok(await categories.updateCategory(ok<CategoryEntity>(food.update(type: CategoryType.income))));

      expect(await updateTransaction(ok(transaction.update(note: 'Phở bò'))), isA<GPOk<TransactionEntity>>());
    });

    test('switches to a transfer without judging the category it drops', () async {
      final transaction = await filedUnderFood();
      await categories.deleteCategory('cat-food');

      final result = await updateTransaction(ok(transaction.update(type: TransactionType.transfer, destinationAccountId: 'acc-bank')));

      expect(result, isA<GPOk<TransactionEntity>>());
      expect((await stored(transaction.id)).categoryId, isNull);
    });

    test('clears the category with nothing to judge', () async {
      final transaction = await filedUnderFood();

      expect(await updateTransaction(ok(transaction.update(clearCategory: true))), isA<GPOk<TransactionEntity>>());
      expect((await stored(transaction.id)).categoryId, isNull);
    });
  });

  group('the stored row', () {
    test('a transaction deleted meanwhile is not found', () async {
      final transaction = await filedUnderFood();
      await transactions.deleteTransaction(transaction.id);

      expect(await updateTransaction(ok(transaction.update(categoryId: 'cat-rent'))), const GPErr<TransactionEntity>(GPNotFoundFailure()));
    });

    test('a stale edit is reported as a conflict, not judged by its category', () async {
      // A pull wrote version 2; `cat-deleted` would be refused if the category were judged first.
      final transaction = await filedUnderFood();
      await (db.update(db.transactionsTable)..where((t) => t.id.equals(transaction.id))).write(const TransactionsTableCompanion(version: Value(2)));

      final result = await updateTransaction(ok(transaction.update(categoryId: 'cat-deleted')));

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
      final edit = ok(
        TransactionEntity.create(
          id: 'tx-unreadable',
          type: TransactionType.expense,
          accountId: 'acc-cash',
          amount: Money(1, 'VND'),
          occurredAt: DateTime.utc(1970),
          createdAt: DateTime.utc(1970),
          updatedAt: DateTime.utc(1970),
          categoryId: 'cat-food',
        ),
      );

      expect(await updateTransaction(edit), const GPErr<TransactionEntity>(GPDatabaseFailure()));
    });
  });
}
