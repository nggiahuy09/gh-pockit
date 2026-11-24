import 'package:drift/drift.dart';

import '../../../../core/database/owner_context.dart';
import '../../../../core/utils/clock.dart';
import '../../../accounts/data/daos/account_dao.dart';
import '../../../accounts/data/mapper/account_mapper.dart';
import '../../../categories/data/daos/category_dao.dart';
import '../../../categories/data/seed/default_categories.dart';
import '../daos/transaction_dao.dart';
import '../mapper/transaction_mapper.dart';
import 'benchmark_dataset_generator.dart';
import 'benchmark_dataset_size_enum.dart';

/// Debug and profile builds only. Writes past the repositories in one transaction (ADR-0025): through `createTransaction`, 50k rows would be 50k
/// commits, each re-running every open watch. Nothing it writes reaches the outbox, so the dataset never syncs.
final class BenchmarkDatasetSeeder {
  const BenchmarkDatasetSeeder({
    required AccountDao accountDao,
    required CategoryDao categoryDao,
    required GPClock clock,
    required BenchmarkDatasetGenerator generator,
    required TransactionDao transactionDao,
    required GPOwnerContext ownerContext,
  }) : _accountDao = accountDao,
       _categoryDao = categoryDao,
       _clock = clock,
       _generator = generator,
       _transactionDao = transactionDao,
       _ownerContext = ownerContext;

  final AccountDao _accountDao;
  final CategoryDao _categoryDao;
  final GPClock _clock;
  final BenchmarkDatasetGenerator _generator;
  final TransactionDao _transactionDao;
  final GPOwnerContext _ownerContext;

  /// Returns how many transactions were written: 0 once the owner has any, so a restart does not double the dataset. Runs after the category seed,
  /// or every row lands uncategorised.
  Future<int> seed(BenchmarkDatasetSize size) async {
    final ownerId = _ownerContext.current;
    if (await _transactionDao.hasAnyTransaction(ownerId)) return 0;

    final categories = await _categoryDao.watchCategories(ownerId: ownerId).first;
    final now = _clock.nowUtc();
    final dataset = _generator.generate(
      categoryIds: {for (final row in categories) ?DefaultCategory.fromNameKey(row.nameKey ?? ''): row.id},
      size: size,
      now: now,
    );
    final deletedIds = dataset.deletedIds;
    final transactions = dataset.transactions;

    return _transactionDao.transaction(() async {
      for (final account in dataset.accounts) {
        await _accountDao.insertAccount(account.toInsert(ownerId));
      }
      await _transactionDao.insertTransactions([
        for (final transaction in transactions)
          deletedIds.contains(transaction.id) ? transaction.toInsert(ownerId).copyWith(deletedAt: Value(now.millisecondsSinceEpoch)) : transaction.toInsert(ownerId),
      ]);

      return transactions.length;
    });
  }
}
