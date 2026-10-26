import 'package:meta/meta.dart';

import '../../../../core/domain/loggable.dart';
import '../../../../core/domain/use_case.dart';
import '../entities/account_entity.dart';
import '../repositories/account_repository.dart';

final class WatchAccountUseCase with GPStreamUseCase<WatchAccountInput, AccountEntity?> {
  const WatchAccountUseCase(this._repository);

  final AccountRepository _repository;

  @override
  Stream<AccountEntity?> execute(WatchAccountInput input) => _repository.watchAccount(input.accountId);
}

@immutable
final class WatchAccountInput implements GPLoggable {
  const WatchAccountInput(this.accountId);

  final String accountId;

  @override
  Map<String, Object?> toLog() => {'account_id': accountId};
}
