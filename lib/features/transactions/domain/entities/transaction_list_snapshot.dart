import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'transaction_entity.dart';

/// Rows the mapper refuses are counted in [unreadableCount] instead of failing the list (ADR-0011).
@immutable
final class TransactionListSnapshot with Equatable {
  TransactionListSnapshot({required List<TransactionEntity> transactions, required this.unreadableCount, required this.hasMore}) : _transactions = transactions {
    if (unreadableCount < 0) throw ArgumentError.value(unreadableCount, 'unreadableCount', 'must not be negative');
  }

  final List<TransactionEntity> _transactions;
  final int unreadableCount;

  /// The window came back full, refused rows included, so a larger window may hold more.
  final bool hasMore;

  List<TransactionEntity> get transactions => List.unmodifiable(_transactions);

  int get rowCount => _transactions.length + unreadableCount;

  @override
  List<Object?> get props => [_transactions, unreadableCount, hasMore];

  @override
  String toString() => 'TransactionListSnapshot(transactions: ${_transactions.length}, unreadableCount: $unreadableCount, hasMore: $hasMore)';
}
