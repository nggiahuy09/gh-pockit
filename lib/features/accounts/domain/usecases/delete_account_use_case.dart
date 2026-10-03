import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

/// Deletes an account, unless a live transaction still touches it (ADR-0010) — the way every caller deletes one (W4 flex).
///
/// **The rule is about what deleting means, not about storage.** Nothing breaks when an account with transactions is soft-deleted: readers already tolerate
/// a deleted parent, because sync can produce one whatever this class does. What breaks is the user's picture. The account's balance disappears from every
/// screen while its transfers keep moving the accounts at their other end. Cascading instead would soft-delete those transfers too and rewrite the history
/// of accounts the user never touched. So the answer is no, and the message points to archiving, which exists for exactly this — out of the pickers and
/// lists, with the history and the sync kept.
///
/// `AccountRepository.deleteAccount` does not check, and says so; this is the check. Outside the write's transaction, as ADR-0010 accepts: a sync can
/// still slip a transaction in between the question and the delete, and readers tolerate the result.
///
/// **Failures:** [GPValidationCode.accountHasTransactions]; a [GPDatabaseFailure] when the question itself cannot be answered, in which case nothing is
/// deleted; and everything `AccountRepository.deleteAccount` returns — [GPNotFoundFailure] for an account that is already gone.
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
