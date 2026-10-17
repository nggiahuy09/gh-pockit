import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';

/// Forwards on purpose (ADR-0013).
class UpdateAccountUseCase {
  const UpdateAccountUseCase({required AccountRepository accountRepository}) : _accounts = accountRepository;

  final AccountRepository _accounts;

  Future<GPResult<AccountEntity>> call(AccountEntity account) => _accounts.updateAccount(account);
}
