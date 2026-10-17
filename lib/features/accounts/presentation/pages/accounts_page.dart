import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/error/failure_message.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/widgets/empty_state.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_balance.dart';
import 'package:ghpockit/features/accounts/presentation/bloc/accounts_cubit.dart';
import 'package:ghpockit/features/accounts/presentation/widgets/account_balance_list.dart';
import 'package:go_router/go_router.dart';

/// Reads an [AccountsCubit] from the tree; the route builder provides it. Laid out as the canvas's "Màn Tài khoản" artboard.
class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<AccountsCubit, AccountsState>(
      builder: (BuildContext context, AccountsState state) {
        final failure = state.failure;
        final accounts = state.balances;
        // The empty state carries its own add button: two on one screen would be one too many.
        final showAdd = accounts == null || accounts.isNotEmpty;

        final Widget body;
        if (accounts == null && failure != null) {
          // No retry button: the query stays live, so the list comes back by itself once the data does.
          body = GPEmptyState(icon: const Icon(Icons.error_outline), title: failure.message(l10n), message: l10n.accounts.errorMessage);
        } else if (accounts == null) {
          body = const AccountListSkeleton();
        } else if (accounts.isEmpty) {
          // Its own button rather than "tap +": the dock's + on this tab adds a transaction, not an account.
          body = GPEmptyState(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            title: l10n.accounts.emptyTitle,
            message: l10n.accounts.emptyMessage,
            actionLabel: l10n.accounts.add,
            onAction: () => context.pushNamed(RouteNames.newAccount),
          );
        } else {
          body = _AccountList(balances: accounts);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.accounts.title),
            actions: <Widget>[
              if (showAdd) IconButton(icon: const Icon(Icons.add), tooltip: l10n.accounts.add, onPressed: () => context.pushNamed(RouteNames.newAccount)),
            ],
          ),
          body: body,
        );
      },
    );
  }
}

class _AccountList extends StatelessWidget {
  const _AccountList({required this.balances});

  final List<AccountBalance> balances;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final caption = context.text.bodySmall.copyWith(color: context.colors.onSurfaceVariant);

    return ListView(
      // Explicit padding replaces the automatic one, so the shell's dock inset is added back by hand.
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.xs, spacing.md, spacing.md + MediaQuery.paddingOf(context).bottom),
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l10n.accounts.count(balances.length), style: context.text.titleSmall.copyWith(color: context.colors.onSurfaceVariant)),
                ),
              ),
              Text(l10n.accounts.balanceColumn, style: caption),
            ],
          ),
        ),
        SizedBox(height: spacing.sm),
        AccountBalanceCard(balances: balances),
      ],
    );
  }
}
