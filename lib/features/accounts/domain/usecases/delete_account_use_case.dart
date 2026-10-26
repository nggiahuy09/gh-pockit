import 'package:meta/meta.dart';

import '../../../../core/domain/loggable.dart';
import '../../../../core/domain/use_case.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../repositories/account_repository.dart';

/// The check runs outside the delete's transaction, a race ADR-0010 accepts.
final class DeleteAccountUseCase with GPUseCase<DeleteAccountInput, void> {
  const DeleteAccountUseCase(this._accountRepository, this._transactionRepository);

  final AccountRepository _accountRepository;
  final TransactionRepository _transactionRepository;

  @override
  Future<GPResult<void>> execute(DeleteAccountInput input) async {
    switch (await _transactionRepository.hasLiveTransactions(input.accountId)) {
      case GPErr(:final failure):
        return GPErr(failure);
      case GPOk(value: true):
        return const GPErr(GPValidationFailure(GPValidationCode.accountHasTransactions));
      case GPOk(value: false):
        return _accountRepository.deleteAccount(input.accountId);
    }
  }
}

@immutable
final class DeleteAccountInput implements GPLoggable {
  const DeleteAccountInput(this.accountId);

  final String accountId;

  @override
  Map<String, Object?> toLog() => {'account_id': accountId};
}
