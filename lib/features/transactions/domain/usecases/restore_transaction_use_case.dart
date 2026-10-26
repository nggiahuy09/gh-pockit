import 'package:meta/meta.dart';

import '../../../../core/domain/loggable.dart';
import '../../../../core/domain/use_case.dart';
import '../../../../core/error/result.dart';
import '../repositories/transaction_repository.dart';

final class RestoreTransactionUseCase with GPUseCase<RestoreTransactionInput, void> {
  const RestoreTransactionUseCase(this._repository);

  final TransactionRepository _repository;

  @override
  Future<GPResult<void>> execute(RestoreTransactionInput input) => _repository.restoreTransaction(input.transactionId);
}

@immutable
final class RestoreTransactionInput implements GPLoggable {
  const RestoreTransactionInput(this.transactionId);

  final String transactionId;

  @override
  Map<String, Object?> toLog() => {'transaction_id': transactionId};
}
