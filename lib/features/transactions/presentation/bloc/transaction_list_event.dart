part of 'transaction_list_bloc.dart';

@immutable
sealed class TransactionListEvent {
  const TransactionListEvent();
}

final class TransactionListStarted extends TransactionListEvent {
  const TransactionListStarted();
}

/// Replaces the whole filter: a null field means no filter on it, not "keep the old one". Fields mean what they mean on [TransactionQuery].
final class TransactionListFilterChanged extends TransactionListEvent {
  const TransactionListFilterChanged({this.accountIds, this.categoryIds, this.types, this.from, this.to});

  final Set<String>? accountIds;
  final Set<String>? categoryIds;
  final Set<TransactionType>? types;
  final DateTime? from;
  final DateTime? to;
}

/// Safe to send on every scroll frame near the end: each page is asked for once.
final class TransactionListLoadMoreRequested extends TransactionListEvent {
  const TransactionListLoadMoreRequested();
}

final class _TransactionListWatchRequested extends TransactionListEvent {
  const _TransactionListWatchRequested(this.query);

  final TransactionQuery query;
}
