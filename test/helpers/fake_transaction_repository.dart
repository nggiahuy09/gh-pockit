import 'dart:async';

import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_balance.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_list_snapshot.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

/// Every [watchTransactions] call opens a [FakeWatch] the test drives by hand; [log] records each `listen #n` / `cancel #n` in the order they happen.
class FakeTransactionRepository implements TransactionRepository {
  /// With no [balances], each call gets a fresh one-empty-list stream, as `FakeAccountRepository` does.
  FakeTransactionRepository({this.balances});

  final Stream<List<AccountBalance>>? balances;

  final List<FakeWatch> watches = <FakeWatch>[];
  final List<String> log = <String>[];

  @override
  Stream<TransactionListSnapshot> watchTransactions(TransactionQuery query) {
    final index = watches.length;
    final watch = FakeWatch._(
      query,
      StreamController<TransactionListSnapshot>(onListen: () => log.add('listen #$index'), onCancel: () => log.add('cancel #$index')),
    );
    watches.add(watch);

    return watch._controller.stream;
  }

  @override
  Stream<TransactionEntity?> watchTransaction(String id) => throw UnimplementedError();

  @override
  Future<GPResult<TransactionEntity>> createTransaction({
    required TransactionType type,
    required String accountId,
    required Money amount,
    required DateTime occurredAt,
    String? destinationAccountId,
    String? categoryId,
    String? note,
  }) => throw UnimplementedError();

  @override
  Future<GPResult<TransactionEntity>> updateTransaction(TransactionEntity transaction) => throw UnimplementedError();

  @override
  Future<GPResult<void>> deleteTransaction(String id) => throw UnimplementedError();

  @override
  Future<GPResult<void>> restoreTransaction(String id) => throw UnimplementedError();

  @override
  Stream<List<AccountBalance>> watchAccountBalances() => balances ?? Stream<List<AccountBalance>>.value(const <AccountBalance>[]);

  @override
  Future<GPResult<bool>> hasLiveTransactions(String accountId) => throw UnimplementedError();
}

class FakeWatch {
  FakeWatch._(this.query, this._controller);

  final TransactionQuery query;
  final StreamController<TransactionListSnapshot> _controller;

  bool get isListened => _controller.hasListener;

  void emit(TransactionListSnapshot snapshot) => _controller.add(snapshot);

  void fail(Object error) => _controller.addError(error);
}
