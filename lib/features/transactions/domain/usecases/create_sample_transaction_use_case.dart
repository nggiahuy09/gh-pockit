import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

/// Debug builds only: one expense in the oldest account, creating a cash account first when there is none.
class CreateSampleTransactionUseCase {
  const CreateSampleTransactionUseCase({required AccountRepository accountRepository, required TransactionRepository transactionRepository, required GPClock clock})
    : _accounts = accountRepository,
      _transactions = transactionRepository,
      _clock = clock;

  static const int sampleAmountMinorUnits = 45000;
  static const String sampleCurrencyCode = 'VND';

  final AccountRepository _accounts;
  final TransactionRepository _transactions;
  final GPClock _clock;

  Future<GPResult<TransactionEntity>> call({required String accountName, required String note}) async {
    final List<AccountEntity> existing;
    try {
      existing = await _accounts.watchAccounts().first;
    } on GPFailure catch (failure) {
      return GPErr<TransactionEntity>(failure);
    }

    final AccountEntity account;
    if (existing.isNotEmpty) {
      account = existing.first;
    } else {
      final created = await _accounts.createAccount(name: accountName, type: AccountType.cash, initialBalance: Money.zero(sampleCurrencyCode));
      switch (created) {
        case GPOk<AccountEntity>(:final value):
          account = value;
        case GPErr<AccountEntity>(:final failure):
          return GPErr<TransactionEntity>(failure);
      }
    }

    return _transactions.createTransaction(
      type: TransactionType.expense,
      accountId: account.id,
      amount: Money(sampleAmountMinorUnits, account.initialBalance.currencyCode),
      occurredAt: _clock.nowUtc(),
      note: note,
    );
  }
}
