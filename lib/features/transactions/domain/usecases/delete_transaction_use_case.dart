import 'package:meta/meta.dart';

import '../../../../core/domain/loggable.dart';
import '../../../../core/domain/use_case.dart';
import '../../../../core/error/result.dart';
import '../repositories/transaction_repository.dart';

final class DeleteTransactionUseCase with GPUseCase<DeleteTransactionInput, void> {
  const DeleteTransactionUseCase(this._repository);

  final TransactionRepository _repository;

  @override
  Future<GPResult<void>> execute(DeleteTransactionInput input) => _repository.deleteTransaction(input.transactionId);
}

@immutable
final class DeleteTransactionInput implements GPLoggable {
  const DeleteTransactionInput(this.transactionId);

  final String transactionId;

  @override
  Map<String, Object?> toLog() => {'transaction_id': transactionId};
}
