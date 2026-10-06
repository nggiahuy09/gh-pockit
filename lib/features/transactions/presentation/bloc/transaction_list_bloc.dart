import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/core/bloc/restartable.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_list_snapshot.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/usecases/watch_transactions_use_case.dart';
import 'package:meta/meta.dart';

part 'transaction_list_event.dart';
part 'transaction_list_state.dart';

/// Paging is one live query whose limit grows, not offset pages (ADR-0011). Only the private watch event subscribes, one watch at a time (ADR-0012).
class TransactionListBloc extends Bloc<TransactionListEvent, TransactionListState> {
  TransactionListBloc({required WatchTransactionsUseCase watchTransactions}) : _watchTransactions = watchTransactions, super(const TransactionListState()) {
    on<TransactionListStarted>(_onStarted);
    on<TransactionListFilterChanged>(_onFilterChanged);
    on<TransactionListLoadMoreRequested>(_onLoadMoreRequested);
    on<_TransactionListWatchRequested>(_onWatchRequested, transformer: restartable());
  }

  /// About four screens of rows. A guess until W8 measures the list's first frame.
  static const pageSize = 50;

  final WatchTransactionsUseCase _watchTransactions;

  void _onStarted(TransactionListStarted event, Emitter<TransactionListState> emit) {
    if (state.query != null) return;

    _watch(emit, TransactionQuery(limit: pageSize));
  }

  void _onFilterChanged(TransactionListFilterChanged event, Emitter<TransactionListState> emit) {
    final current = state.query;
    if (current == null) return;

    // Compared at the current limit, so re-sending the filter already in force is a no-op that keeps the scroll depth; only a real change resets to one page.
    final next = TransactionQuery(limit: current.limit, accountIds: event.accountIds, categoryIds: event.categoryIds, types: event.types, from: event.from, to: event.to);
    if (next == current) return;

    _watch(emit, next.withLimit(pageSize));
  }

  void _onLoadMoreRequested(TransactionListLoadMoreRequested event, Emitter<TransactionListState> emit) {
    final current = state.query;
    final snapshot = state.snapshot;
    if (current == null || snapshot == null || !snapshot.hasMore) return;

    // Grown from the rows on screen (unreadable ones included, ADR-0011), not from `current.limit`: a repeat request for the same snapshot asks for the same
    // window and is dropped, so a scroll listener firing every frame costs one query, and the window never shrinks.
    final limit = snapshot.rowCount + pageSize;
    if (limit <= current.limit) return;

    // The old rows stay on screen while the larger window loads: they are its prefix.
    _watch(emit, current.withLimit(limit), snapshot: snapshot);
  }

  /// Emits the new query at once, so the next event already sees it, and leaves the subscription to [_onWatchRequested].
  void _watch(Emitter<TransactionListState> emit, TransactionQuery query, {TransactionListSnapshot? snapshot}) {
    emit(TransactionListState(query: query, snapshot: snapshot));
    add(_TransactionListWatchRequested(query));
  }

  Future<void> _onWatchRequested(_TransactionListWatchRequested event, Emitter<TransactionListState> emit) {
    // Until `restartable` cancels it, a superseded watch can still deliver: whatever it sends is dropped once its query is no longer the state's.
    bool isCurrent() => event.query == state.query;

    return emit.forEach<TransactionListSnapshot>(
      _watchTransactions(event.query),
      onData: (snapshot) => isCurrent() ? TransactionListState(query: event.query, snapshot: snapshot) : state,
      onError: (error, stackTrace) {
        // Anything but a `GPFailure` is a bug: rethrown, never shown as a sentence (ADR-0006).
        if (error is! GPFailure) Error.throwWithStackTrace(error, stackTrace);

        return isCurrent() ? TransactionListState(query: event.query, snapshot: state.snapshot, failure: error) : state;
      },
    );
  }
}
