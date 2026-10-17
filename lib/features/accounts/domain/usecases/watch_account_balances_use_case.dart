import 'package:ghpockit/features/accounts/domain/entities/account_balance.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

/// Forwards on purpose (ADR-0013). The query is the transactions repository's, which already reads accounts (ADR-0019).
class WatchAccountBalancesUseCase {
  const WatchAccountBalancesUseCase({required TransactionRepository transactionRepository}) : _transactions = transactionRepository;

  final TransactionRepository _transactions;

  Stream<List<AccountBalance>> call() => _transactions.watchAccountBalances();
}
