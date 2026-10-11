part of 'transaction_list_bloc.dart';

@immutable
final class TransactionListState {
  const TransactionListState({this.query, this.snapshot, this.failure})
    : assert(query != null || (snapshot == null && failure == null), 'rows and failures come from a watched query');

  final TransactionQuery? query;

  /// While a larger window loads, still the smaller window's rows — a prefix of the larger one (ADR-0011).
  final TransactionListSnapshot? snapshot;

  /// Set alongside [snapshot], not instead of it: rows already on screen survive an error.
  final GPFailure? failure;

  bool get isLoading => snapshot == null && failure == null;

  bool get hasMore => snapshot?.hasMore ?? false;

  /// A full snapshot with fewer rows than [query] allows can only be the window from before the last load more, so the larger one has not answered yet —
  /// a failure counts as its answer.
  bool get isLoadingMore {
    final rows = snapshot;
    final window = query;

    return failure == null && rows != null && window != null && rows.hasMore && rows.rowCount < window.limit;
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is TransactionListState && other.query == query && other.snapshot == snapshot && other.failure == failure;

  @override
  int get hashCode => Object.hash(query, snapshot, failure);

  @override
  String toString() => 'TransactionListState(query: $query, snapshot: $snapshot, failure: $failure)';
}
