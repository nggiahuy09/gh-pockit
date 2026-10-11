import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:meta/meta.dart';

/// Rows the mapper refuses are counted in [unreadableCount] instead of failing the list (ADR-0011).
@immutable
final class TransactionListSnapshot {
  TransactionListSnapshot({required List<TransactionEntity> transactions, required this.unreadableCount, required this.hasMore})
    : transactions = List<TransactionEntity>.unmodifiable(transactions) {
    if (unreadableCount < 0) throw ArgumentError.value(unreadableCount, 'unreadableCount', 'must not be negative');
  }

  final List<TransactionEntity> transactions;
  final int unreadableCount;

  /// The window came back full, refused rows included, so a larger window *may* hold more.
  final bool hasMore;

  int get rowCount => transactions.length + unreadableCount;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TransactionListSnapshot || other.unreadableCount != unreadableCount || other.hasMore != hasMore) return false;
    if (other.transactions.length != transactions.length) return false;

    for (var i = 0; i < transactions.length; i++) {
      if (other.transactions[i] != transactions[i]) return false;
    }

    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(transactions), unreadableCount, hasMore);

  @override
  String toString() => 'TransactionListSnapshot(transactions: ${transactions.length}, unreadableCount: $unreadableCount, hasMore: $hasMore)';
}
