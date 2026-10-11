import 'package:ghpockit/features/transactions/domain/entities/transaction_list_snapshot.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

/// Forwards on purpose: a BLoC reaches the domain only through use cases, never a repository (ADR-0013).
class WatchTransactionsUseCase {
  const WatchTransactionsUseCase({required TransactionRepository transactionRepository}) : _transactions = transactionRepository;

  final TransactionRepository _transactions;

  Stream<TransactionListSnapshot> call(TransactionQuery query) => _transactions.watchTransactions(query);
}
