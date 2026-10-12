import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';

/// Forwards on purpose (ADR-0013).
class WatchAccountUseCase {
  const WatchAccountUseCase({required AccountRepository accountRepository}) : _accounts = accountRepository;

  final AccountRepository _accounts;

  Stream<AccountEntity?> call(String id) => _accounts.watchAccount(id);
}
