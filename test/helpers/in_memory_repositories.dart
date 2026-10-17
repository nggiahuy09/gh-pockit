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
class InMemoryRepositories {
  InMemoryRepositories({FakeClock? clock}) : clock = clock ?? FakeClock() {
    // Otherwise drift keeps a cancelled stream cached behind `Timer.run`, and a widget test fails on a timer still pending at teardown.
    db = GPAppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final logger = RecordingLogger(clock: this.clock);
    accounts = AccountRepositoryImpl(
      dao: AccountDao(db),
      clock: this.clock,
      uuidGenerator: FakeUuidGenerator(prefix: 'acc'),
      logger: logger,
      ownerId: localOwnerId,
    );
    categories = CategoryRepositoryImpl(
      dao: CategoryDao(db),
      clock: this.clock,
      uuidGenerator: FakeUuidGenerator(prefix: 'cat'),
      logger: logger,
      ownerId: localOwnerId,
    );
    transactions = TransactionRepositoryImpl(
      dao: TransactionDao(db),
      clock: this.clock,
      uuidGenerator: FakeUuidGenerator(prefix: 'tx'),
      logger: logger,
      ownerId: localOwnerId,
    );
  }

  final FakeClock clock;
  late final GPAppDatabase db;
  late final AccountRepositoryImpl accounts;
  late final CategoryRepositoryImpl categories;
  late final TransactionRepositoryImpl transactions;

  Future<void> close() => db.close();
}
