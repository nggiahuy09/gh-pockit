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
import '../../../../helpers/results.dart';

const _refused = GPErr<void>(GPValidationFailure(GPValidationCode.accountHasTransactions));

Future<TransactionEntity> _record(TransactionRepositoryImpl transactions, {TransactionType type = TransactionType.expense, String? destinationAccountId}) async => okValue(
  await transactions.createTransaction(
    amount: Money(125000, 'VND'),
    type: type,
    occurredAt: DateTime.utc(2026, 9, 30, 5, 30),
    accountId: 'acc-cash',
    destinationAccountId: destinationAccountId,
  ),
);

Future<int?> _deletedAtOf(GPAppDatabase db, String accountId) async => (await (db.select(db.accountsTable)..where((t) => t.id.equals(accountId))).getSingle()).deletedAt;

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
    logger = RecordingLogger(clock);

    accounts = AccountRepositoryImpl(clock: clock, dao: AccountDao(db), logger: logger, uuidGenerator: uuid, ownerId: localOwnerId);
    transactions = TransactionRepositoryImpl(clock: clock, dao: TransactionDao(db), logger: logger, uuidGenerator: uuid, ownerId: localOwnerId);
    deleteAccount = DeleteAccountUseCase(accounts, transactions);

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

  tearDown(() => db.close());

  test('deletes an account no transaction touches', () async {
    await _record(transactions);

    expect(await deleteAccount.execute(const DeleteAccountInput('acc-bank')), const GPOk<void>(null));
    expect(await _deletedAtOf(db, 'acc-bank'), clock.nowEpochMillis());
  });

  test('refuses an account a live transaction is on — pointing to archive — and leaves it live', () async {
    await _record(transactions);

    expect(await deleteAccount.execute(const DeleteAccountInput('acc-cash')), _refused);
    expect(await _deletedAtOf(db, 'acc-cash'), isNull);
  });

  test("refuses a transfer's destination too — the side whose balance would move with nothing to show for it", () async {
    await _record(transactions, type: TransactionType.transfer, destinationAccountId: 'acc-bank');

    expect(await deleteAccount.execute(const DeleteAccountInput('acc-bank')), _refused);
  });

  test('deletes the account once its transactions are deleted', () async {
    final transaction = await _record(transactions);
    await transactions.deleteTransaction(transaction.id);

    expect(await deleteAccount.execute(const DeleteAccountInput('acc-cash')), const GPOk<void>(null));
  });

  test("reports an account that is not there as not found — the repository's answer, unchanged", () async {
    expect(await deleteAccount.execute(const DeleteAccountInput('acc-missing')), const GPErr<void>(GPNotFoundFailure()));
  });

  test('deletes nothing when the question cannot be answered', () async {
    final failing = DeleteAccountUseCase(
      accounts,
      TransactionRepositoryImpl(clock: clock, dao: _LookupFailingTransactionDao(db), logger: logger, uuidGenerator: uuid, ownerId: localOwnerId),
    );

    expect(await failing.execute(const DeleteAccountInput('acc-cash')), const GPErr<void>(GPDatabaseFailure()));
    expect(await _deletedAtOf(db, 'acc-cash'), isNull);
  });
}

final class _LookupFailingTransactionDao extends TransactionDao {
  _LookupFailingTransactionDao(super.attachedDatabase);

  @override
  Future<bool> hasLiveTransactions({required String accountId, required String ownerId}) => Future.error(Exception('disk I/O error'));
}
