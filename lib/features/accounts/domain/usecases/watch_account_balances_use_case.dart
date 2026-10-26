import '../../../../core/domain/use_case.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../entities/account_balance.dart';

/// The query is the transactions repository's, which already reads accounts (ADR-0019).
final class WatchAccountBalancesUseCase with GPStreamUseCase<GPNoInput, List<AccountBalance>> {
  const WatchAccountBalancesUseCase(this._repository);

  final TransactionRepository _repository;

  @override
  Stream<List<AccountBalance>> execute(GPNoInput input) => _repository.watchAccountBalances();
}
