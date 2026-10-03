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

/// `CreateTransactionUseCase` (W4 flex) over the real repositories on an in-memory database — no fake repository, for the reason
/// `account_repository_impl_test.dart` gives, and because the answer that matters here is the one a real `watchCategory` gives: live, deleted, another
/// owner's, or unreadable.
///
/// What is covered is rule 3 of ADR-0010 and nothing the repository already owns: the repository's own failures are only checked to come back unchanged.
void main() {
  late GPAppDatabase db;
  late CreateTransactionUseCase createTransaction;

  final occurredAt = DateTime.utc(2026, 9, 30, 5, 30);

  setUp(() async {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    final clock = FakeClock(DateTime.utc(2026, 9, 30, 9));
    final uuid = FakeUuidGenerator();
    final logger = RecordingLogger(clock: clock);

    createTransaction = CreateTransactionUseCase(
      transactionRepository: TransactionRepositoryImpl(dao: TransactionDao(db), clock: clock, uuidGenerator: uuid, logger: logger, ownerId: localOwnerId),
      categoryRepository: CategoryRepositoryImpl(dao: CategoryDao(db), clock: clock, uuidGenerator: uuid, logger: logger, ownerId: localOwnerId),
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

    Future<void> category(String id, {String type = 'expense', String ownerId = localOwnerId, int? deletedAt}) => db
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

    await category('cat-food');
    await category('cat-salary', type: 'income');
    await category('cat-deleted', deletedAt: 1);
    await category('cat-theirs', ownerId: 'someone-else');
    // A type this build does not know, written by a newer one: the category mapper refuses the row, so `watchCategory` errors.
    await category('cat-unreadable', type: 'savings');
  });

  tearDown(() async {
    await db.close();
  });

  Future<GPResult<TransactionEntity>> create({TransactionType type = TransactionType.expense, String? categoryId, String? destinationAccountId, int amount = 125000}) =>
      createTransaction(
        type: type,
        accountId: 'acc-cash',
        amount: Money(amount, 'VND'),
        occurredAt: occurredAt,
        destinationAccountId: destinationAccountId,
        categoryId: categoryId,
      );

  Future<List<TransactionRow>> storedRows() => db.select(db.transactionsTable).get();

  test('files an expense under an expense category and an income under an income one', () async {
    expect(await create(categoryId: 'cat-food'), isA<GPOk<TransactionEntity>>());
    expect(await create(type: TransactionType.income, categoryId: 'cat-salary'), isA<GPOk<TransactionEntity>>());

    expect((await storedRows()).map((row) => row.categoryId), ['cat-food', 'cat-salary']);
  });

  test('refuses an expense under an income category, and the reverse — and writes nothing', () async {
    const mismatch = GPErr<TransactionEntity>(GPValidationFailure(GPValidationCode.transactionCategoryTypeMismatch));

    expect(await create(categoryId: 'cat-salary'), mismatch);
    expect(await create(type: TransactionType.income, categoryId: 'cat-food'), mismatch);
    expect(await storedRows(), isEmpty);
  });

  test('refuses a category that is not live — deleted, missing, or not the owner’s — as not found', () async {
    // A missing one is the case the use case changes the answer for: the repository alone would reach the foreign key and report local storage failing.
    for (final categoryId in ['cat-deleted', 'cat-missing', 'cat-theirs']) {
      expect(await create(categoryId: categoryId), const GPErr<TransactionEntity>(GPNotFoundFailure()), reason: categoryId);
    }
    expect(await storedRows(), isEmpty);
  });

  test('a category that cannot be read is a database failure, and nothing is written', () async {
    expect(await create(categoryId: 'cat-unreadable'), const GPErr<TransactionEntity>(GPDatabaseFailure()));
    expect(await storedRows(), isEmpty);
  });

  test('an uncategorised transaction needs no category rule', () async {
    expect(await create(), isA<GPOk<TransactionEntity>>());
    expect((await storedRows()).single.categoryId, isNull);
  });

  test("a transfer's leftover category is not judged — the entity drops it", () async {
    // What a form sends when the type was switched to transfer after a category was picked. Judging it would refuse a field that is no longer on screen.
    final result = await create(type: TransactionType.transfer, destinationAccountId: 'acc-bank', categoryId: 'cat-deleted');

    expect(result, isA<GPOk<TransactionEntity>>());
    expect((await storedRows()).single.categoryId, isNull);
  });

  test("the repository's failures come back unchanged", () async {
    expect(await create(categoryId: 'cat-food', amount: 0), const GPErr<TransactionEntity>(GPValidationFailure(GPValidationCode.transactionAmountNotPositive)));
    expect(
      await createTransaction(type: TransactionType.expense, accountId: 'acc-missing', amount: Money(125000, 'VND'), occurredAt: occurredAt),
      const GPErr<TransactionEntity>(GPNotFoundFailure()),
    );
  });

  test("the category is judged first, so its failure is the one returned when the entity's rules fail as well", () async {
    // The documented price of checking it outside the repository. An amount of zero under the wrong kind of category reports the category.
    expect(await create(categoryId: 'cat-salary', amount: 0), const GPErr<TransactionEntity>(GPValidationFailure(GPValidationCode.transactionCategoryTypeMismatch)));
  });
}
