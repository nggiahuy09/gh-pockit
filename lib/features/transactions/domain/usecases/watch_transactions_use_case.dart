import 'package:meta/meta.dart';

import '../../../../core/domain/loggable.dart';
import '../../../../core/domain/use_case.dart';
import '../entities/transaction_list_snapshot.dart';
import '../entities/transaction_query.dart';
import '../repositories/transaction_repository.dart';

final class WatchTransactionsUseCase with GPStreamUseCase<WatchTransactionsInput, TransactionListSnapshot> {
  const WatchTransactionsUseCase(this._repository);

  final TransactionRepository _repository;

  @override
  Stream<TransactionListSnapshot> execute(WatchTransactionsInput input) => _repository.watchTransactions(input.query);
}

@immutable
final class WatchTransactionsInput implements GPLoggable {
  const WatchTransactionsInput(this.query);

  final TransactionQuery query;

  @override
  Map<String, Object?> toLog() => {'limit': query.limit};
}
