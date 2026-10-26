import 'package:meta/meta.dart';

import '../../../../core/domain/loggable.dart';
import '../../../../core/domain/use_case.dart';
import '../../../../core/error/result.dart';
import '../entities/account_entity.dart';
import '../repositories/account_repository.dart';

final class UpdateAccountUseCase with GPUseCase<UpdateAccountInput, AccountEntity> {
  const UpdateAccountUseCase(this._repository);

  final AccountRepository _repository;

  @override
  Future<GPResult<AccountEntity>> execute(UpdateAccountInput input) => _repository.updateAccount(input.account);
}

@immutable
final class UpdateAccountInput implements GPLoggable {
  const UpdateAccountInput(this.account);

  final AccountEntity account;

  @override
  Map<String, Object?> toLog() => {'account_id': account.id, 'version': account.version};
}
