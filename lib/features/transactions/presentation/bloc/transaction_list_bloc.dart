import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

import '../../../../app/di/injector.dart';
import '../../../../core/bloc/transformers.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/transaction_list_snapshot.dart';
import '../../domain/entities/transaction_query.dart';
import '../../domain/entities/transaction_type.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/usecases/watch_transactions_use_case.dart';

part 'transaction_list_event.dart';

part 'transaction_list_state.dart';

/// Paging is one live query whose limit grows, not offset pages (ADR-0011). Only the private watch event subscribes, one watch at a time (ADR-0012).
final class TransactionListBloc extends Bloc<TransactionListEvent, TransactionListState> {
  TransactionListBloc() : super(const TransactionListInitState()) {
    on<TransactionListRequestEvent>(_eventHandler, transformer: sequential());
    on<_TransactionListWatchEvent>(_watchHandler, transformer: restartable());

    add(const _TransactionListStartEvent());
  }

  final _watchTransactions = WatchTransactionsUseCase(getIt.get<TransactionRepository>());

  /// About four screens of rows; a guess until the list's first frame is measured.
  static const pageSize = 50;

  void _eventHandler(TransactionListRequestEvent event, Emitter<TransactionListState> emit) {
    switch (event) {
      case _TransactionListStartEvent():
        _startHandler(emit);
      case TransactionListFilterChangeEvent():
        _filterChangeHandler(event, emit);
      case TransactionListLoadMoreEvent():
        _loadMoreHandler(emit);
    }
  }

  void _startHandler(Emitter<TransactionListState> emit) {
    if (state.query != null) return;

    _watch(TransactionQuery(limit: pageSize), null, emit);
  }

  void _filterChangeHandler(TransactionListFilterChangeEvent event, Emitter<TransactionListState> emit) {
    final query = state.query;
    if (query == null) return;

    // Compared at the current limit, so re-sending the filter in force keeps the scroll depth; only a real change resets to one page.
    final next = TransactionQuery(accountIds: event.accountIds, categoryIds: event.categoryIds, types: event.types, from: event.from, to: event.to, limit: query.limit);
    if (next == query) return;

    _watch(next.withLimit(pageSize), null, emit);
  }

  void _loadMoreHandler(Emitter<TransactionListState> emit) {
    final query = state.query;
    final snapshot = state.snapshot;
    if (query == null || snapshot == null || !snapshot.hasMore) return;

    // Grown from the rows on screen, not from the limit: a repeat request for the same snapshot asks for the same window and is dropped, so a scroll
    // listener firing every frame costs one query (ADR-0011).
    final limit = snapshot.rowCount + pageSize;
    if (limit <= query.limit) return;

    _watch(query.withLimit(limit), snapshot, emit);
  }

  void _watch(TransactionQuery query, TransactionListSnapshot? snapshot, Emitter<TransactionListState> emit) {
    emit(TransactionListLoadingState(query, snapshot));
    add(_TransactionListWatchEvent(query));
  }

  Future<void> _watchHandler(_TransactionListWatchEvent event, Emitter<TransactionListState> emit) {
    final query = event.query;

    // Until `restartable` cancels it, a superseded watch can still deliver: whatever it sends is dropped once its query is no longer the state's.
    return emit.forEach(
      _watchTransactions.execute(WatchTransactionsInput(query)),
      onData: (snapshot) => _isCurrent(query) ? TransactionListLoadedState(query, snapshot) : state,
      onError: (error, stackTrace) {
        if (error is! GPFailure) Error.throwWithStackTrace(error, stackTrace);
        return _isCurrent(query) ? TransactionListLoadErrorState(query, state.snapshot, error) : state;
      },
    );
  }

  bool _isCurrent(TransactionQuery query) => query == state.query;
}
