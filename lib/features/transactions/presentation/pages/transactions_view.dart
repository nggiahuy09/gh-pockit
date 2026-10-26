import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/bloc/bloc_extension.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_extension.dart';
import '../../../../core/localization/localization_scope.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transaction_list_snapshot.dart';
import '../bloc/transaction_deletion_bloc.dart';
import '../bloc/transaction_list_bloc.dart';
import '../transaction_days.dart';
import '../transaction_entity_extension.dart';
import '../transaction_form_outcome_enum.dart';
import '../widgets/transaction_list_widget.dart';

final class TransactionsView extends StatelessWidget {
  const TransactionsView({super.key, required this.clock});

  final GPClock clock;

  /// Replaces whatever snackbar is up: only the latest delete can be taken back (ADR-0017).
  void _handleDeletion(BuildContext context, TransactionDeletionState state) {
    final locale = context.l10n;
    final viewLocale = locale.transactions;
    final messenger = ScaffoldMessenger.of(context);
    // Captured now: the snackbar outlives the gesture.
    final bloc = context.read<TransactionDeletionBloc>();

    switch (state) {
      case TransactionDeletionInitState() || TransactionDeletionDeleteLoadingState() || TransactionDeletionRestoreLoadingState() || TransactionDeletionRestoredState():
        return;
      case TransactionDeletionDeletedState(:final transactionId):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(viewLocale.deleted),
              action: SnackBarAction(label: viewLocale.undo, onPressed: () => bloc.maybeAdd(TransactionDeletionRestoreEvent(transactionId))),
            ),
          );
      case TransactionDeletionErrorState(:final failure):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.getMessage(locale))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewLocale = context.l10n.transactions;

    return BlocListener<TransactionDeletionBloc, TransactionDeletionState>(
      listenWhen: (_, next) => next is TransactionDeletionDeletedState || next is TransactionDeletionErrorState,
      listener: (_, state) => _handleDeletion(context, state),
      child: Scaffold(
        appBar: AppBar(title: Text(viewLocale.title)),
        body: BlocBuilder<TransactionListBloc, TransactionListState>(
          builder: (_, state) => _TransactionsBody(state: state, today: clock.nowUtc().toLocal()),
        ),
      ),
    );
  }
}

final class _TransactionsBody extends StatelessWidget {
  const _TransactionsBody({required this.state, required this.today});

  final TransactionListState state;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;
    final viewLocale = locale.transactions;
    final snapshot = state.snapshot;
    final failure = switch (state) {
      TransactionListLoadErrorState(:final failure) => failure,
      TransactionListInitState() || TransactionListLoadingState() || TransactionListLoadedState() => null,
    };

    // No retry button: the query stays registered, so the list comes back with the next write (ADR-0011).
    if (failure != null && (snapshot == null || snapshot.rowCount == 0)) {
      return SafeArea(
        top: false,
        child: GPEmptyState(icon: const Icon(Icons.error_outline), message: viewLocale.errorBody, title: failure.getMessage(locale)),
      );
    }

    if (snapshot == null) return const TransactionListSkeletonWidget();

    if (snapshot.rowCount == 0) {
      return SafeArea(
        top: false,
        child: GPEmptyState(icon: const Icon(Icons.receipt_long_outlined), message: viewLocale.emptyBody, title: viewLocale.emptyTitle),
      );
    }

    return _TransactionList(failure: failure, snapshot: snapshot, today: today, hasMore: state.hasMore);
  }
}

final class _TransactionList extends StatelessWidget {
  const _TransactionList({required this.failure, required this.snapshot, required this.today, required this.hasMore});

  final GPFailure? failure;
  final TransactionListSnapshot snapshot;
  final DateTime today;
  final bool hasMore;

  /// How close to the end, in pixels, the next window starts loading.
  static const _loadMoreThreshold = 600.0;

  bool _handleScroll(BuildContext context, ScrollNotification notification) {
    // The bloc drops a request for a window it already has, so firing on every frame near the end is harmless.
    if (hasMore && notification.metrics.extentAfter < _loadMoreThreshold) context.read<TransactionListBloc>().add(const TransactionListLoadMoreEvent());
    return false;
  }

  Future<void> _handleOpen(BuildContext context, TransactionEntity transaction) async {
    final bloc = context.read<TransactionDeletionBloc>();
    final outcome = await context.pushNamed<TransactionFormOutcome>(RouteNames.editTransaction, pathParameters: {'transactionId': transaction.id});

    if (outcome == TransactionFormOutcome.deleted) bloc.maybeAdd(TransactionDeletionUndoOfferEvent(transaction.id));
  }

  /// Completes true once the row is deleted; false puts a swiped row back. The undo snackbar comes from the deletion bloc's listener.
  Future<bool> _handleDelete(BuildContext context, TransactionEntity transaction) async {
    final bloc = context.read<TransactionDeletionBloc>();
    final confirmed = await showGPDialog<bool>(
      actions: [
        GPDialogAction.cancel(value: false, label: context.l10n.root.cancel),
        GPDialogAction(value: true, variant: GPButtonVariant.danger, label: context.l10n.transactions.delete),
      ],
      content: _DeleteConfirmContent(transaction: transaction),
      context: context,
      icon: Icons.delete_outline,
      tone: GPDialogTone.danger,
      title: context.l10n.transactions.deleteConfirmTitle,
    );
    if (!(confirmed ?? false) || bloc.isClosed) return false;

    bloc.add(TransactionDeletionDeleteEvent(transaction.id));
    final outcome = await bloc.stream.firstWhere((state) => state is TransactionDeletionDeletedState || state is TransactionDeletionDeleteErrorState, orElse: () => bloc.state);
    return outcome is TransactionDeletionDeletedState;
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;
    final viewLocale = locale.transactions;
    final failure = this.failure;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) => _handleScroll(context, notification),
      child: CustomScrollView(
        slivers: [
          if (failure != null) SliverToBoxAdapter(child: TransactionListBannerWidget.error(message: failure.getMessage(locale))),
          if (snapshot.unreadableCount > 0) SliverToBoxAdapter(child: TransactionListBannerWidget.notice(message: viewLocale.unreadable(snapshot.unreadableCount))),
          for (final day in groupByLocalDay(snapshot.transactions))
            SliverMainAxisGroup(
              slivers: [
                TransactionDayHeaderWidget(
                  label: getDayLabel(locale: locale, date: day.date, today: today),
                ),
                SliverToBoxAdapter(
                  child: TransactionDayCardWidget(
                    transactions: day.transactions,
                    onOpen: (transaction) => unawaited(_handleOpen(context, transaction)),
                    onDelete: (transaction) => _handleDelete(context, transaction),
                  ),
                ),
              ],
            ),
          SliverSafeArea(
            top: false,
            sliver: SliverToBoxAdapter(
              child: hasMore ? TransactionListFooterWidget(label: viewLocale.loadingMore) : SizedBox(height: context.spacing.md),
            ),
          ),
        ],
      ),
    );
  }
}

/// The row itself, so the user confirms the one they meant to swipe. Asked because a scroll that drifts sideways can swipe a row away.
final class _DeleteConfirmContent extends StatelessWidget {
  const _DeleteConfirmContent({required this.transaction});

  final TransactionEntity transaction;

  @override
  Widget build(BuildContext context) => Row(
    spacing: context.spacing.smd,
    children: [
      Expanded(child: Text(transaction.getTitle(context.l10n), maxLines: 2, overflow: TextOverflow.ellipsis)),
      GPMoneyText(amount: transaction.amount, tone: transaction.moneyTone),
    ],
  );
}
