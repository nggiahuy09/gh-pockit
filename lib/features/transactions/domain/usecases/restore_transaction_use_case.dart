import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

/// Forwards on purpose (ADR-0013). No category rule: coming back creates no new filing, the case `UpdateTransactionUseCase` skips too.
class RestoreTransactionUseCase {
  const RestoreTransactionUseCase({required TransactionRepository transactionRepository}) : _transactions = transactionRepository;

  final TransactionRepository _transactions;

  Future<GPResult<void>> call(String id) => _transactions.restoreTransaction(id);
}
