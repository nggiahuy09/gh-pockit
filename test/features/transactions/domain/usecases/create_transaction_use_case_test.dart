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
import 'package:ghpockit/features/transactions/domain/usecases/create_transaction_use_case.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/fake_uuid_generator.dart';
import '../../../../helpers/recording_logger.dart';

final _occurredAt = DateTime.utc(2026, 9, 30, 5, 30);

/// Real repositories on in-memory SQL: what matters is the answer a real `watchCategory` gives (live, deleted, another owner's, unreadable).
void main() {
  late GPAppDatabase db;
  late CreateTransactionUseCase createTransaction;

  setUp(() async {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    final clock = FakeClock(DateTime.utc(2026, 9, 30, 9));
    final uuid = FakeUuidGenerator();
    final logger = RecordingLogger(clock);

    createTransaction = CreateTransactionUseCase(
      CategoryRepositoryImpl(clock: clock, dao: CategoryDao(db), logger: logger, uuidGenerator: uuid, ownerId: localOwnerId),
      TransactionRepositoryImpl(clock: clock, dao: TransactionDao(db), logger: logger, uuidGenerator: uuid, ownerId: localOwnerId),
    );

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
    await _insertCategory(db, 'cat-salary', type: 'income');
    await _insertCategory(db, 'cat-deleted', deletedAt: 1);
    await _insertCategory(db, 'cat-theirs', ownerId: 'someone-else');
    // A type this build does not know, so the mapper refuses the row and `watchCategory` errors.
    await _insertCategory(db, 'cat-unreadable', type: 'savings');
  });

  tearDown(() => db.close());

  test('files an expense under an expense category and an income under an income one', () async {
    expect(await _create(createTransaction, categoryId: 'cat-food'), isA<GPOk<TransactionEntity>>());
    expect(await _create(createTransaction, type: TransactionType.income, categoryId: 'cat-salary'), isA<GPOk<TransactionEntity>>());

    expect((await db.select(db.transactionsTable).get()).map((row) => row.categoryId), ['cat-food', 'cat-salary']);
  });

  test('refuses an expense under an income category, and the reverse — and writes nothing', () async {
    const mismatch = GPErr<TransactionEntity>(GPValidationFailure(GPValidationCode.transactionCategoryTypeMismatch));

    expect(await _create(createTransaction, categoryId: 'cat-salary'), mismatch);
    expect(await _create(createTransaction, type: TransactionType.income, categoryId: 'cat-food'), mismatch);
    expect(await db.select(db.transactionsTable).get(), isEmpty);
  });

  test('refuses a category that is not live — deleted, missing, or not the owner’s — as not found', () async {
    // Without the use case, a missing category would reach the foreign key and come back as a database failure.
    for (final categoryId in const ['cat-deleted', 'cat-missing', 'cat-theirs']) {
      expect(await _create(createTransaction, categoryId: categoryId), const GPErr<TransactionEntity>(GPNotFoundFailure()), reason: categoryId);
    }
    expect(await db.select(db.transactionsTable).get(), isEmpty);
  });

  test('a category that cannot be read is a database failure, and nothing is written', () async {
    expect(await _create(createTransaction, categoryId: 'cat-unreadable'), const GPErr<TransactionEntity>(GPDatabaseFailure()));
    expect(await db.select(db.transactionsTable).get(), isEmpty);
  });

  test('an uncategorised transaction needs no category rule', () async {
    expect(await _create(createTransaction), isA<GPOk<TransactionEntity>>());
    expect((await db.select(db.transactionsTable).get()).single.categoryId, isNull);
  });

  test("a transfer's leftover category is not judged — the entity drops it", () async {
    final result = await _create(createTransaction, type: TransactionType.transfer, categoryId: 'cat-deleted', destinationAccountId: 'acc-bank');

    expect(result, isA<GPOk<TransactionEntity>>());
    expect((await db.select(db.transactionsTable).get()).single.categoryId, isNull);
  });

  test("the repository's failures come back unchanged", () async {
    expect(
      await _create(createTransaction, categoryId: 'cat-food', amountMinorUnits: 0),
      const GPErr<TransactionEntity>(GPValidationFailure(GPValidationCode.transactionAmountNotPositive)),
    );
    expect(await _create(createTransaction, accountId: 'acc-missing'), const GPErr<TransactionEntity>(GPNotFoundFailure()));
  });

  test("the category is judged first, so its failure is the one returned when the entity's rules fail as well", () async {
    expect(
      await _create(createTransaction, categoryId: 'cat-salary', amountMinorUnits: 0),
      const GPErr<TransactionEntity>(GPValidationFailure(GPValidationCode.transactionCategoryTypeMismatch)),
    );
  });

  test('the input logs ids and the type, never the amount or the note', () {
    final input = CreateTransactionInput(amount: Money(125000, 'VND'), type: TransactionType.expense, occurredAt: _occurredAt, accountId: 'acc-cash', note: 'Phở');

    expect(input.toLog(), {'type': 'expense', 'account_id': 'acc-cash'});
  });
}

Future<void> _insertCategory(GPAppDatabase db, String id, {String ownerId = localOwnerId, String type = 'expense', int? deletedAt}) => db
    .into(db.categoriesTable)
    .insert(
      CategoriesTableCompanion.insert(
        id: id,
        ownerId: ownerId,
        name: Value(id),
        type: type,
        isSystem: false,
        createdAt: 0,
        updatedAt: 0,
        version: 1,
        deletedAt: Value(deletedAt),
      ),
    );

Future<GPResult<TransactionEntity>> _create(
  CreateTransactionUseCase useCase, {
  TransactionType type = TransactionType.expense,
  String accountId = 'acc-cash',
  String? categoryId,
  String? destinationAccountId,
  int amountMinorUnits = 125000,
}) => useCase.execute(
  CreateTransactionInput(
    amount: Money(amountMinorUnits, 'VND'),
    type: type,
    occurredAt: _occurredAt,
    accountId: accountId,
    categoryId: categoryId,
    destinationAccountId: destinationAccountId,
  ),
);
