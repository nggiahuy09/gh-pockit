import 'package:meta/meta.dart';

import '../../../../core/domain/loggable.dart';
import '../../../../core/domain/use_case.dart';
import '../../../../core/error/result.dart';
import '../../../../core/money/money.dart';
import '../entities/account_entity.dart';
import '../entities/account_type.dart';
import '../repositories/account_repository.dart';

/// The currency chosen here is the account's for good (ADR-0010).
final class CreateAccountUseCase with GPUseCase<CreateAccountInput, AccountEntity> {
  const CreateAccountUseCase(this._repository);

  final AccountRepository _repository;

  @override
  Future<GPResult<AccountEntity>> execute(CreateAccountInput input) => _repository.createAccount(initialBalance: input.initialBalance, type: input.type, name: input.name);
}

@immutable
final class CreateAccountInput implements GPLoggable {
  const CreateAccountInput(this.initialBalance, this.type, this.name);

  final Money initialBalance;
  final AccountType type;
  final String name;

  @override
  Map<String, Object?> toLog() => {'type': type.storageValue, 'currency_code': initialBalance.currencyCode};
}
