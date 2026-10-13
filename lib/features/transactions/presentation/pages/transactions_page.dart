import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/failure_message.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/core/widgets/empty_state.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_list_snapshot.dart';
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_list_bloc.dart';
import 'package:ghpockit/features/transactions/presentation/transaction_days.dart';
import 'package:ghpockit/features/transactions/presentation/widgets/transaction_list_parts.dart';
import 'package:go_router/go_router.dart';

/// Reads a [TransactionListBloc] from the tree; the route builder provides it.
class TransactionsPage extends StatelessWidget {
  const TransactionsPage({required this.clock, super.key});

  /// For "Today" and "Yesterday".
  final GPClock clock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.transactions.title)),
      body: BlocBuilder<TransactionListBloc, TransactionListState>(
        builder: (BuildContext context, TransactionListState state) {
          final snapshot = state.snapshot;
          final failure = state.failure;

          if (failure != null && (snapshot == null || snapshot.rowCount == 0)) return _ErrorState(failure: failure);
          if (snapshot == null) return const TransactionListSkeleton();
          if (snapshot.rowCount == 0) {
            return SafeArea(
              top: false,
              child: GPEmptyState(icon: const Icon(Icons.receipt_long_outlined), title: l10n.transactions.emptyTitle, message: l10n.transactions.emptyMessage),
            );
          }

          return _TransactionList(snapshot: snapshot, failure: failure, hasMore: state.hasMore, today: clock.nowUtc().toLocal());
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.failure});

  final GPFailure failure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // No retry button: the query stays registered, so the list comes back with the next write (ADR-0011).
    return SafeArea(
      top: false,
      child: GPEmptyState(icon: const Icon(Icons.error_outline), title: failure.message(l10n), message: l10n.transactions.errorMessage),
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({required this.snapshot, required this.failure, required this.hasMore, required this.today});

  /// How close to the end, in pixels, the next window starts loading.
  static const double _loadMoreThreshold = 600;

  final TransactionListSnapshot snapshot;
  final GPFailure? failure;
  final bool hasMore;
  final DateTime today;

  bool _onScroll(BuildContext context, ScrollNotification notification) {
    // The bloc drops a request for a window it already has, so firing on every frame near the end is harmless.
    if (hasMore && notification.metrics.extentAfter < _loadMoreThreshold) context.read<TransactionListBloc>().add(const TransactionListLoadMoreRequested());
    return false;
  }

  Future<void> _open(BuildContext context, TransactionEntity transaction) =>
      context.pushNamed<void>(RouteNames.editTransaction, pathParameters: <String, String>{'transactionId': transaction.id});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final failure = this.failure;
    final days = groupByLocalDay(snapshot.transactions);

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) => _onScroll(context, notification),
      child: CustomScrollView(
        slivers: <Widget>[
          if (failure != null) SliverToBoxAdapter(child: TransactionListBanner.error(message: failure.message(l10n))),
          if (snapshot.unreadableCount > 0) SliverToBoxAdapter(child: TransactionListBanner.notice(message: l10n.transactions.unreadable(snapshot.unreadableCount))),
          for (final day in days)
            SliverMainAxisGroup(
              slivers: <Widget>[
                TransactionDayHeader(
                  label: dayLabel(day.date, today: today, l10n: l10n),
                ),
                SliverToBoxAdapter(
                  child: TransactionDayCard(
                    transactions: day.transactions,
                    onOpen: (TransactionEntity transaction) => unawaited(_open(context, transaction)),
                  ),
                ),
              ],
            ),
          SliverSafeArea(
            top: false,
            sliver: SliverToBoxAdapter(
              child: hasMore ? TransactionListFooter(label: l10n.transactions.loadingMore) : SizedBox(height: spacing.md),
            ),
          ),
        ],
      ),
    );
  }
}
