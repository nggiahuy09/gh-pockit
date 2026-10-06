import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_list_snapshot.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/usecases/watch_transactions_use_case.dart';

import '../../../../helpers/fake_transaction_repository.dart';

void main() {
  test('watches the query it is given and passes the stream through, errors included', () async {
    final repository = FakeTransactionRepository();
    final query = TransactionQuery(limit: 50);
    final snapshot = TransactionListSnapshot(transactions: const [], unreadableCount: 0, hasMore: false);
    final received = <Object>[];

    final subscription = WatchTransactionsUseCase(transactionRepository: repository)(query).listen(received.add, onError: received.add);
    addTearDown(subscription.cancel);
    repository.watches.single
      ..emit(snapshot)
      ..fail(const GPDatabaseFailure());
    await pumpEventQueue();

    expect(repository.watches.single.query, query);
    expect(received, [snapshot, const GPDatabaseFailure()]);
  });
}
