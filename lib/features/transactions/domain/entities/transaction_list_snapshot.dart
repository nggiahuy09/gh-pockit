import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'transaction_entity.dart';
import 'transaction_list_item.dart';

/// Rows the mapper refuses are counted in [unreadableCount] instead of failing the list (ADR-0011).
@immutable
final class TransactionListSnapshot with Equatable {
  TransactionListSnapshot({required List<TransactionListItem> items, required this.unreadableCount, required this.hasMore}) : _items = items {
    if (unreadableCount < 0) throw ArgumentError.value(unreadableCount, 'unreadableCount', 'must not be negative');
  }

  final List<TransactionListItem> _items;
  final int unreadableCount;

  /// The window came back full, refused rows included, so a larger window may hold more.
  final bool hasMore;

  List<TransactionListItem> get items => List.unmodifiable(_items);

  /// The rows without the names they show, for a reader that needs only the transactions.
  List<TransactionEntity> get transactions => List.unmodifiable(_items.map((item) => item.transaction));

  int get rowCount => _items.length + unreadableCount;

  @override
  List<Object?> get props => [_items, unreadableCount, hasMore];

  @override
  String toString() => 'TransactionListSnapshot(items: ${_items.length}, unreadableCount: $unreadableCount, hasMore: $hasMore)';
}
