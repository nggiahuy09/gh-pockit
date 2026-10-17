import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';

/// Forwards on purpose: a BLoC reaches the domain only through use cases, never a repository (ADR-0013).
class WatchAccountsUseCase {
  const WatchAccountsUseCase({required AccountRepository accountRepository}) : _accounts = accountRepository;

  final AccountRepository _accounts;

  Stream<List<AccountEntity>> call({bool includeArchived = false}) => _accounts.watchAccounts(includeArchived: includeArchived);
}
