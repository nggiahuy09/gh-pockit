import '../../../../core/domain/use_case.dart';
import '../entities/account_entity.dart';
import '../repositories/account_repository.dart';

final class WatchAccountsUseCase with GPStreamUseCase<GPNoInput, List<AccountEntity>> {
  const WatchAccountsUseCase(this._repository);

  final AccountRepository _repository;

  @override
  Stream<List<AccountEntity>> execute(GPNoInput input) => _repository.watchAccounts();
}
