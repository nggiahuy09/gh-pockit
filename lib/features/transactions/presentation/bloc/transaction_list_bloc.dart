import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_list_snapshot.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:meta/meta.dart';

part 'transaction_list_event.dart';
part 'transaction_list_state.dart';

/// Paging is one live query whose limit grows, not offset pages (ADR-0011).
class TransactionListBloc extends Bloc<TransactionListEvent, TransactionListState> {
  TransactionListBloc() : super(const TransactionListState()) {
    on<TransactionListStarted>(_onStarted);
    on<TransactionListFilterChanged>(_onFilterChanged);
    on<TransactionListLoadMoreRequested>(_onLoadMoreRequested);
  }

  /// About four screens of rows. A guess until W8 measures the list's first frame.
  static const pageSize = 50;

  void _onStarted(TransactionListStarted event, Emitter<TransactionListState> emit) {
    if (state.query != null) return;

    emit(TransactionListState(query: TransactionQuery(limit: pageSize)));
  }

  void _onFilterChanged(TransactionListFilterChanged event, Emitter<TransactionListState> emit) {
    final current = state.query;
    if (current == null) return;

    // Compared at the current limit, so re-sending the filter already in force is a no-op that keeps the scroll depth; only a real change resets to one page.
    final next = TransactionQuery(limit: current.limit, accountIds: event.accountIds, categoryIds: event.categoryIds, types: event.types, from: event.from, to: event.to);
    if (next == current) return;

    emit(TransactionListState(query: next.withLimit(pageSize)));
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
    emit(TransactionListState(query: current.withLimit(limit), snapshot: snapshot));
  }
}
