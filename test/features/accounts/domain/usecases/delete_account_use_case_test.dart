import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/data/daos/account_dao.dart';
import 'package:ghpockit/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:ghpockit/features/accounts/domain/usecases/delete_account_use_case.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/fake_uuid_generator.dart';
import '../../../../helpers/recording_logger.dart';

/// Real repositories on one in-memory database: the rule under test spans the account and transaction tables.
void main() {
  late GPAppDatabase db;
  late FakeClock clock;
  late FakeUuidGenerator uuid;
  late RecordingLogger logger;
  late AccountRepositoryImpl accounts;
  late TransactionRepositoryImpl transactions;
  late DeleteAccountUseCase deleteAccount;

  setUp(() async {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    clock = FakeClock(DateTime.utc(2026, 9, 30, 9));
    uuid = FakeUuidGenerator();
    logger = RecordingLogger(clock: clock);

    accounts = AccountRepositoryImpl(dao: AccountDao(db), clock: clock, uuidGenerator: uuid, logger: logger, ownerId: localOwnerId);
    transactions = TransactionRepositoryImpl(dao: TransactionDao(db), clock: clock, uuidGenerator: uuid, logger: logger, ownerId: localOwnerId);
    deleteAccount = DeleteAccountUseCase(accountRepository: accounts, transactionRepository: transactions);

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
  });

  tearDown(() async {
    await db.close();
  });

  Future<TransactionEntity> record({TransactionType type = TransactionType.expense, String? destinationAccountId}) async {
    final result = await transactions.createTransaction(
      type: type,
      accountId: 'acc-cash',
      amount: Money(125000, 'VND'),
      occurredAt: DateTime.utc(2026, 9, 30, 5, 30),
      destinationAccountId: destinationAccountId,
    );

    return (result as GPOk<TransactionEntity>).value;
  }

  Future<int?> deletedAtOf(String accountId) async => (await (db.select(db.accountsTable)..where((t) => t.id.equals(accountId))).getSingle()).deletedAt;

  const refused = GPErr<void>(GPValidationFailure(GPValidationCode.accountHasTransactions));

  test('deletes an account no transaction touches', () async {
    await record();

    expect(await deleteAccount('acc-bank'), const GPOk<void>(null));
    expect(await deletedAtOf('acc-bank'), clock.nowEpochMillis());
  });

  test('refuses an account a live transaction is on — pointing to archive — and leaves it live', () async {
    await record();

    expect(await deleteAccount('acc-cash'), refused);
    expect(await deletedAtOf('acc-cash'), isNull);
  });

  test("refuses a transfer's destination too — the side whose balance would move with nothing to show for it", () async {
    await record(type: TransactionType.transfer, destinationAccountId: 'acc-bank');

    expect(await deleteAccount('acc-bank'), refused);
  });

  test('deletes the account once its transactions are deleted', () async {
    final transaction = await record();
    await transactions.deleteTransaction(transaction.id);

    expect(await deleteAccount('acc-cash'), const GPOk<void>(null));
  });

  test("reports an account that is not there as not found — the repository's answer, unchanged", () async {
    expect(await deleteAccount('acc-missing'), const GPErr<void>(GPNotFoundFailure()));
  });

  test('deletes nothing when the question cannot be answered', () async {
    final failing = DeleteAccountUseCase(
      accountRepository: accounts,
      transactionRepository: TransactionRepositoryImpl(dao: LookupFailingTransactionDao(db), clock: clock, uuidGenerator: uuid, logger: logger, ownerId: localOwnerId),
    );

    expect(await failing('acc-cash'), const GPErr<void>(GPDatabaseFailure()));
    expect(await deletedAtOf('acc-cash'), isNull);
  });
}

class LookupFailingTransactionDao extends TransactionDao {
  LookupFailingTransactionDao(super.attachedDatabase);

  @override
  Future<bool> hasLiveTransactions(String ownerId, String accountId) => Future<bool>.error(Exception('disk I/O error'));
}
