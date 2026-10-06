import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

/// Fails with [GPValidationCode.accountHasTransactions] while a live transaction touches the account (ADR-0010). The check runs outside the delete's
/// transaction, a race the ADR accepts.
class DeleteAccountUseCase {
  const DeleteAccountUseCase({required AccountRepository accountRepository, required TransactionRepository transactionRepository})
    : _accounts = accountRepository,
      _transactions = transactionRepository;

  final AccountRepository _accounts;
  final TransactionRepository _transactions;

  Future<GPResult<void>> call(String accountId) async {
    switch (await _transactions.hasLiveTransactions(accountId)) {
      case GPErr<bool>(:final failure):
        return GPErr<void>(failure);
      case GPOk<bool>(value: true):
        return const GPErr<void>(GPValidationFailure(GPValidationCode.accountHasTransactions));
      case GPOk<bool>(value: false):
        return _accounts.deleteAccount(accountId);
    }
  }
}
