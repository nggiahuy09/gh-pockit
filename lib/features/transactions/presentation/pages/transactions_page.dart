import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/failure_message.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/core/widgets/button.dart';
import 'package:ghpockit/core/widgets/empty_state.dart';
import 'package:ghpockit/core/widgets/money_text.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_list_snapshot.dart';
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_deletion_cubit.dart';
import 'package:ghpockit/features/transactions/presentation/bloc/transaction_list_bloc.dart';
import 'package:ghpockit/features/transactions/presentation/pages/transaction_form_page.dart';
import 'package:ghpockit/features/transactions/presentation/transaction_days.dart';
import 'package:ghpockit/features/transactions/presentation/transaction_labels.dart';
import 'package:ghpockit/features/transactions/presentation/widgets/transaction_list_parts.dart';
import 'package:go_router/go_router.dart';

/// Reads a [TransactionListBloc] and a [TransactionDeletionCubit] from the tree; the route builder provides both.
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

  Future<void> _open(BuildContext context, TransactionEntity transaction) async {
    final undo = _UndoOffer.of(context);
    final outcome = await context.pushNamed<TransactionFormOutcome>(RouteNames.editTransaction, pathParameters: <String, String>{'transactionId': transaction.id});

    if (outcome == TransactionFormOutcome.deleted) undo.show(transaction.id);
  }

  Future<bool> _delete(BuildContext context, TransactionEntity transaction) async {
    final undo = _UndoOffer.of(context);
    if (!await _confirmDelete(context, transaction)) return false;

    switch (await undo.deletion.delete(transaction.id)) {
      case GPOk<void>():
        undo.show(transaction.id);
        return true;
      case GPErr<void>(:final failure):
        undo.report(failure);
        return false;
    }
  }

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
                    onDelete: (TransactionEntity transaction) => _delete(context, transaction),
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

/// Asked before a swipe deletes, since a scroll that drifts sideways can swipe a row away. True only on an explicit Delete; dismissing keeps the row.
/// The undo still follows a confirmed delete (ADR-0017).
Future<bool> _confirmDelete(BuildContext context, TransactionEntity transaction) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(l10n.transactions.deleteConfirmTitle),
      // The row itself, so the user confirms the one they meant to swipe.
      content: Row(
        children: <Widget>[
          Expanded(child: Text(transaction.titleIn(l10n), maxLines: 2, overflow: TextOverflow.ellipsis)),
          SizedBox(width: context.spacing.smd),
          GPMoneyText(transaction.amount, tone: transaction.moneyTone),
        ],
      ),
      actions: <Widget>[
        GPButton(label: l10n.root.cancel, variant: GPButtonVariant.text, onPressed: () => Navigator.of(context).pop(false)),
        GPButton(label: l10n.transactions.delete, variant: GPButtonVariant.danger, onPressed: () => Navigator.of(context).pop(true)),
      ],
    ),
  );

  return confirmed ?? false;
}

/// The snackbar after a delete, from a swipe or from the form (ADR-0017). Captured before any await: the messenger outlives the gesture, and the
/// cubit outlives the form that was pushed over the list.
class _UndoOffer {
  _UndoOffer.of(BuildContext context) : messenger = ScaffoldMessenger.of(context), deletion = context.read<TransactionDeletionCubit>(), l10n = context.l10n;

  final ScaffoldMessengerState messenger;
  final TransactionDeletionCubit deletion;
  final GPLocaleBase l10n;

  /// Replaces whatever snackbar is up: only the latest delete can be taken back.
  void show(String id) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.transactions.deleted),
          action: SnackBarAction(label: l10n.transactions.undo, onPressed: () => unawaited(_restore(id))),
        ),
      );
  }

  void report(GPFailure failure) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failure.message(l10n))));
  }

  Future<void> _restore(String id) async {
    if (deletion.isClosed) return;

    if (await deletion.restore(id) case GPErr<void>(:final failure)) report(failure);
  }
}
