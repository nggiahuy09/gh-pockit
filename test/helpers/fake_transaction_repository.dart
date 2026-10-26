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
base class FakeTransactionRepository extends TransactionRepository {
  /// Without [_balances], each call gets a fresh one-empty-list stream.
  FakeTransactionRepository([this._balances]);

  final List<String> _log = [];
  final List<FakeWatch> _watches = [];
  final Stream<List<AccountBalance>>? _balances;

  List<String> get log => List.unmodifiable(_log);

  List<FakeWatch> get watches => List.unmodifiable(_watches);

  @override
  Stream<TransactionListSnapshot> watchTransactions(TransactionQuery query) {
    final index = _watches.length;
    final watch = FakeWatch._(query, StreamController(onListen: () => _log.add('listen #$index'), onCancel: () => _log.add('cancel #$index')));
    _watches.add(watch);

    return watch._controller.stream;
  }

  @override
  Stream<TransactionEntity?> watchTransaction(String id) => throw UnimplementedError();

  @override
  Future<GPResult<TransactionEntity>> createTransaction({
    required Money amount,
    required TransactionType type,
    required DateTime occurredAt,
    required String accountId,
    String? categoryId,
    String? destinationAccountId,
    String? note,
  }) => throw UnimplementedError();

  @override
  Future<GPResult<TransactionEntity>> updateTransaction(TransactionEntity transaction) => throw UnimplementedError();

  @override
  Future<GPResult<void>> deleteTransaction(String id) => throw UnimplementedError();

  @override
  Future<GPResult<void>> restoreTransaction(String id) => throw UnimplementedError();

  @override
  Future<GPResult<bool>> hasLiveTransactions(String accountId) => throw UnimplementedError();

  @override
  Stream<List<AccountBalance>> watchAccountBalances() => _balances ?? Stream.value(const []);
}

final class FakeWatch {
  FakeWatch._(this.query, this._controller);

  final TransactionQuery query;
  final StreamController<TransactionListSnapshot> _controller;

  bool get isListened => _controller.hasListener;

  void emit(TransactionListSnapshot snapshot) => _controller.add(snapshot);

  void fail(Object error) => _controller.addError(error);
}
