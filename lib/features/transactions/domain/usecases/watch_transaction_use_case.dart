import 'package:meta/meta.dart';

import '../../../../core/domain/loggable.dart';
import '../../../../core/domain/use_case.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';

final class WatchTransactionUseCase with GPStreamUseCase<WatchTransactionInput, TransactionEntity?> {
  const WatchTransactionUseCase(this._repository);

  final TransactionRepository _repository;

  @override
  Stream<TransactionEntity?> execute(WatchTransactionInput input) => _repository.watchTransaction(input.transactionId);
}

@immutable
final class WatchTransactionInput implements GPLoggable {
  const WatchTransactionInput(this.transactionId);

  final String transactionId;

  @override
  Map<String, Object?> toLog() => {'transaction_id': transactionId};
}
