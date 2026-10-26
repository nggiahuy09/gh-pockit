part of 'transaction_list_bloc.dart';

@immutable
sealed class TransactionListState with Equatable {
  const TransactionListState(this.query, this.snapshot);

  final TransactionQuery? query;

  /// While a larger window loads, still the smaller window's rows: a prefix of the larger one (ADR-0011).
  final TransactionListSnapshot? snapshot;

  bool get hasMore => snapshot?.hasMore ?? false;

  @override
  List<Object?> get props => [query, snapshot];
}

final class TransactionListInitState extends TransactionListState {
  const TransactionListInitState() : super(null, null);
}

/// With a [snapshot], a larger window is loading under the rows on screen.
final class TransactionListLoadingState extends TransactionListState {
  const TransactionListLoadingState(TransactionQuery super.query, super.snapshot);

  @override
  TransactionQuery get query => super.query!;
}

final class TransactionListLoadedState extends TransactionListState {
  const TransactionListLoadedState(TransactionQuery super.query, TransactionListSnapshot super.snapshot);

  @override
  TransactionQuery get query => super.query!;

  @override
  TransactionListSnapshot get snapshot => super.snapshot!;
}

final class TransactionListLoadErrorState extends TransactionListState {
  const TransactionListLoadErrorState(TransactionQuery super.query, super.snapshot, this.failure);

  final GPFailure failure;

  @override
  TransactionQuery get query => super.query!;

  @override
  List<Object?> get props => [...super.props, failure];
}
