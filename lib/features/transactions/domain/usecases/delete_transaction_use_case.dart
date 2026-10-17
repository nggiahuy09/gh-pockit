import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

/// Forwards on purpose (ADR-0013): deleting a transaction owns no rule (ADR-0010).
class DeleteTransactionUseCase {
  const DeleteTransactionUseCase({required TransactionRepository transactionRepository}) : _transactions = transactionRepository;

  final TransactionRepository _transactions;

  Future<GPResult<void>> call(String id) => _transactions.deleteTransaction(id);
}
