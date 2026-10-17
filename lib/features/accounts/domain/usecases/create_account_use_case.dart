import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';

/// Forwards on purpose (ADR-0013). The currency chosen here is the account's for good (ADR-0010).
class CreateAccountUseCase {
  const CreateAccountUseCase({required AccountRepository accountRepository}) : _accounts = accountRepository;

  final AccountRepository _accounts;

  Future<GPResult<AccountEntity>> call({required String name, required AccountType type, required Money initialBalance}) =>
      _accounts.createAccount(name: name, type: type, initialBalance: initialBalance);
}
