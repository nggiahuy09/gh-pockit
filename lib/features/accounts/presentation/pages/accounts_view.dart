import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/error/failure_extension.dart';
import '../../../../core/localization/localization_scope.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/account_balance.dart';
import '../bloc/accounts_bloc.dart';
import '../widgets/account_balance_list_widget.dart';

/// Laid out as the canvas's "Màn Tài khoản" artboard.
final class AccountsView extends StatelessWidget {
  const AccountsView({super.key});

  void _handleAdd(BuildContext context) => unawaited(context.pushNamed(RouteNames.newAccount));

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;
    final viewLocale = locale.accounts;

    return BlocBuilder<AccountsBloc, AccountsState>(
      builder: (_, state) {
        final balances = state.balances;
        // The empty state carries its own add button: two on one screen would be one too many.
        final showsAdd = balances == null || balances.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text(viewLocale.title),
            actions: [if (showsAdd) IconButton(icon: const Icon(Icons.add), tooltip: viewLocale.add, onPressed: () => _handleAdd(context))],
          ),
          body: _AccountsBody(state: state, onAdd: () => _handleAdd(context)),
        );
      },
    );
  }
}

final class _AccountsBody extends StatelessWidget {
  const _AccountsBody({required this.state, required this.onAdd});

  final AccountsState state;
  final void Function() onAdd;

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;
    final viewLocale = locale.accounts;
    final balances = state.balances;

    if (balances == null) {
      return switch (state) {
        // No retry button: the query stays live, so the list comes back by itself.
        AccountsLoadErrorState(:final failure) => GPEmptyState(icon: const Icon(Icons.error_outline), message: viewLocale.errorBody, title: failure.getMessage(locale)),
        AccountsInitState() || AccountsLoadingState() || AccountsLoadedState() => const AccountListSkeletonWidget(),
      };
    }

    // Its own button rather than "tap +": the dock's + on this tab adds a transaction, not an account.
    if (balances.isEmpty) {
      return GPEmptyState(
        icon: const Icon(Icons.account_balance_wallet_outlined),
        actionLabel: viewLocale.add,
        message: viewLocale.emptyBody,
        title: viewLocale.emptyTitle,
        onAction: onAdd,
      );
    }

    return _AccountList(balances: balances);
  }
}

final class _AccountList extends StatelessWidget {
  const _AccountList({required this.balances});

  final List<AccountBalance> balances;

  @override
  Widget build(BuildContext context) {
    final viewLocale = context.l10n.accounts;
    final spacing = context.spacing;
    final captionColor = context.colors.onSurfaceVariant;

    return ListView(
      // Explicit padding replaces the automatic one, so the shell's dock inset is added back by hand.
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.xs, spacing.md, spacing.md + MediaQuery.paddingOf(context).bottom),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(viewLocale.count(balances.length), style: context.text.titleSmall.copyWith(color: captionColor)),
                ),
              ),
              Text(viewLocale.balanceColumn, style: context.text.bodySmall.copyWith(color: captionColor)),
            ],
          ),
        ),
        SizedBox(height: spacing.sm),
        AccountBalanceCardWidget(balances: balances),
      ],
    );
  }
}
