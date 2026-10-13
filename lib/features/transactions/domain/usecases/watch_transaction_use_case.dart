import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

/// Forwards on purpose (ADR-0013).
class WatchTransactionUseCase {
  const WatchTransactionUseCase({required TransactionRepository transactionRepository}) : _transactions = transactionRepository;

  final TransactionRepository _transactions;

  Stream<TransactionEntity?> call(String id) => _transactions.watchTransaction(id);
}
