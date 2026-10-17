import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/error/failure_message.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/widgets/empty_state.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_balance.dart';
import 'package:ghpockit/features/accounts/presentation/widgets/account_balance_list.dart';
import 'package:ghpockit/features/dashboard/presentation/bloc/home_accounts_cubit.dart';
import 'package:go_router/go_router.dart';

/// The canvas's Home, as far as the data exists: the accounts section with their balances. The month summary and the greeting wait for their data
/// (monthly totals W7, a user with a name P3).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  /// A summary, not the list: the rest is one tap away under "See all".
  static const int accountsShown = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.home.title),
        actions: <Widget>[
          IconButton(tooltip: l10n.settings.title, icon: const Icon(Icons.settings_outlined), onPressed: () => context.goNamed(RouteNames.settings)),
        ],
      ),
      body: BlocBuilder<HomeAccountsCubit, HomeAccountsState>(
        builder: (BuildContext context, HomeAccountsState state) {
          final accounts = state.accounts;
          final failure = state.failure;

          if (accounts == null && failure != null) return GPEmptyState(icon: const Icon(Icons.error_outline), title: failure.message(l10n));
          if (accounts == null) return const Center(child: CircularProgressIndicator());
          if (accounts.isEmpty) {
            return GPEmptyState(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              title: l10n.accounts.emptyTitle,
              message: l10n.accounts.emptyMessage,
              actionLabel: l10n.accounts.add,
              onAction: () => context.pushNamed(RouteNames.newAccount),
            );
          }

          final spacing = context.spacing;
          return ListView(
            // Explicit padding replaces the automatic one, so the shell's dock inset is added back by hand.
            padding: EdgeInsets.fromLTRB(spacing.md, spacing.xs, spacing.md, spacing.md + MediaQuery.paddingOf(context).bottom),
            children: <Widget>[_AccountsSection(accounts: accounts.take(accountsShown).toList())],
          );
        },
      ),
    );
  }
}

class _AccountsSection extends StatelessWidget {
  const _AccountsSection({required this.accounts});

  final List<AccountBalance> accounts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final spacing = context.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.xs),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l10n.accounts.title, style: context.text.headlineSmall.copyWith(color: colors.onBackground)),
                ),
              ),
              TextButton(
                onPressed: () => context.goNamed(RouteNames.accounts),
                style: TextButton.styleFrom(
                  foregroundColor: colors.accentInk,
                  textStyle: context.text.titleSmall.copyWith(fontWeight: FontWeight.w600),
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.symmetric(horizontal: spacing.sm),
                ),
                child: Text(l10n.home.seeAllAccounts),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.xs),
        AccountBalanceCard(balances: accounts),
      ],
    );
  }
}
