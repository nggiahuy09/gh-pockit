import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/error/failure_message.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/widgets/empty_state.dart';
import 'package:ghpockit/core/widgets/money_text.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_balance.dart';
import 'package:ghpockit/features/accounts/presentation/account_type_label.dart';
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
        DecoratedBox(
          decoration: BoxDecoration(color: colors.surface, borderRadius: context.radii.borderLg, boxShadow: context.shadows.small),
          child: ClipRRect(
            borderRadius: context.radii.borderLg,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: <Widget>[
                  for (var i = 0; i < accounts.length; i++) ...<Widget>[
                    if (i > 0) Divider(height: 1, thickness: 1, color: colors.outlineVariant),
                    _AccountRow(balance: accounts[i]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.balance});

  final AccountBalance balance;

  @override
  Widget build(BuildContext context) {
    final account = balance.account;
    final l10n = context.l10n;
    final colors = context.colors;
    final spacing = context.spacing;

    return InkWell(
      onTap: () => context.pushNamed(RouteNames.editAccount, pathParameters: <String, String>{'accountId': account.id}),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: colors.surfaceVariant, shape: BoxShape.circle),
                child: Icon(account.type.icon, size: 20, color: colors.onSurfaceVariant),
              ),
              SizedBox(width: spacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyLarge.copyWith(color: colors.onSurface),
                    ),
                    Text(account.type.labelIn(l10n), style: context.text.bodySmall.copyWith(color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
              SizedBox(width: spacing.smd),
              // Neutral keeps the balance's own sign; red only repeats it for money owed.
              GPMoneyText(
                balance.balance,
                style: context.text.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: balance.balance.isNegative ? colors.expense : colors.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
