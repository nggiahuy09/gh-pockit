import 'package:meta/meta.dart';

import '../../../../core/domain/loggable.dart';
import '../../../../core/domain/use_case.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/clock.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../accounts/domain/entities/account_type.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../entities/transaction_entity.dart';
import '../entities/transaction_type.dart';
import '../repositories/transaction_repository.dart';

/// Debug builds only: one expense in the oldest account, creating a cash account first when there is none.
final class CreateSampleTransactionUseCase with GPUseCase<CreateSampleTransactionInput, TransactionEntity> {
  const CreateSampleTransactionUseCase(this._accountRepository, this._clock, this._transactionRepository);

  final AccountRepository _accountRepository;
  final GPClock _clock;
  final TransactionRepository _transactionRepository;

  static const sampleCurrencyCode = 'VND';
  static const sampleAmountMinorUnits = 45000;

  @override
  Future<GPResult<TransactionEntity>> execute(CreateSampleTransactionInput input) async {
    final List<AccountEntity> existing;
    try {
      existing = await _accountRepository.watchAccounts().first;
    } on GPFailure catch (failure) {
      return GPErr(failure);
    }

    final AccountEntity account;
    if (existing.isNotEmpty) {
      account = existing.first;
    } else {
      switch (await _accountRepository.createAccount(initialBalance: Money.zero(sampleCurrencyCode), type: AccountType.cash, name: input.accountName)) {
        case GPOk(:final value):
          account = value;
        case GPErr(:final failure):
          return GPErr(failure);
      }
    }

    return _transactionRepository.createTransaction(
      amount: Money(sampleAmountMinorUnits, account.initialBalance.currencyCode),
      type: TransactionType.expense,
      occurredAt: _clock.nowUtc(),
      accountId: account.id,
      note: input.note,
    );
  }
}

@immutable
final class CreateSampleTransactionInput implements GPLoggable {
  const CreateSampleTransactionInput({required this.accountName, required this.note});

  final String accountName;
  final String note;

  @override
  Map<String, Object?> toLog() => const {};
}
