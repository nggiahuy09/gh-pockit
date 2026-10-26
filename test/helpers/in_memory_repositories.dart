import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/features/accounts/data/daos/account_dao.dart';
import 'package:ghpockit/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:ghpockit/features/categories/data/daos/category_dao.dart';
import 'package:ghpockit/features/categories/data/repositories/category_repository_impl.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/data/repositories/transaction_repository_impl.dart';

import 'fake_clock.dart';
import 'fake_uuid_generator.dart';
import 'recording_logger.dart';

/// The real account, category and transaction repositories over one in-memory database. No categories are seeded.
final class InMemoryRepositories {
  InMemoryRepositories([FakeClock? clock]) : clock = clock ?? FakeClock() {
    // Otherwise drift keeps a cancelled stream cached behind `Timer.run`, and a widget test fails on a timer still pending at teardown.
    db = GPAppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final logger = RecordingLogger(this.clock);
    accounts = AccountRepositoryImpl(clock: this.clock, dao: AccountDao(db), logger: logger, uuidGenerator: FakeUuidGenerator('acc'), ownerId: localOwnerId);
    categories = CategoryRepositoryImpl(clock: this.clock, dao: CategoryDao(db), logger: logger, uuidGenerator: FakeUuidGenerator('cat'), ownerId: localOwnerId);
    transactions = TransactionRepositoryImpl(clock: this.clock, dao: TransactionDao(db), logger: logger, uuidGenerator: FakeUuidGenerator('tx'), ownerId: localOwnerId);
  }

  late final AccountRepositoryImpl accounts;
  late final CategoryRepositoryImpl categories;
  final FakeClock clock;
  late final GPAppDatabase db;
  late final TransactionRepositoryImpl transactions;

  Future<void> close() => db.close();
}
