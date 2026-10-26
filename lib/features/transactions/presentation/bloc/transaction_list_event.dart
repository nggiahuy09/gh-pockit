part of 'transaction_list_bloc.dart';

@immutable
sealed class TransactionListEvent {
  const TransactionListEvent();
}

@immutable
sealed class TransactionListRequestEvent extends TransactionListEvent {
  const TransactionListRequestEvent();
}

@immutable
final class _TransactionListStartEvent extends TransactionListRequestEvent {
  const _TransactionListStartEvent();
}

/// Replaces the whole filter: a null field means no filter on it, not "keep the old one".
@immutable
final class TransactionListFilterChangeEvent extends TransactionListRequestEvent {
  const TransactionListFilterChangeEvent({Set<String>? accountIds, Set<String>? categoryIds, Set<TransactionType>? types, this.from, this.to})
    : _accountIds = accountIds,
      _categoryIds = categoryIds,
      _types = types;

  final Set<String>? _accountIds;
  final Set<String>? _categoryIds;
  final Set<TransactionType>? _types;
  final DateTime? from;
  final DateTime? to;

  Set<String>? get accountIds => _accountIds == null ? null : Set.unmodifiable(_accountIds);

  Set<String>? get categoryIds => _categoryIds == null ? null : Set.unmodifiable(_categoryIds);

  Set<TransactionType>? get types => _types == null ? null : Set.unmodifiable(_types);
}

/// Safe to send on every scroll frame near the end: each window is asked for once.
@immutable
final class TransactionListLoadMoreEvent extends TransactionListRequestEvent {
  const TransactionListLoadMoreEvent();
}

@immutable
final class _TransactionListWatchEvent extends TransactionListEvent {
  const _TransactionListWatchEvent(this.query);

  final TransactionQuery query;
}
