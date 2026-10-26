import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/error/failure_extension.dart';
import '../../../../core/localization/localization_scope.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../accounts/domain/entities/account_balance.dart';
import '../../../accounts/presentation/widgets/account_balance_list_widget.dart';
import '../bloc/home_accounts_bloc.dart';

/// The canvas's Home, as far as the data exists: the month summary and the greeting wait for their data.
final class HomeView extends StatelessWidget {
  const HomeView({super.key});

  /// A summary, not the list: the rest is one tap away under "See all".
  static const accountsShown = 3;

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(locale.home.title),
        actions: [IconButton(tooltip: locale.settings.title, icon: const Icon(Icons.settings_outlined), onPressed: () => context.goNamed(RouteNames.settings))],
      ),
      body: BlocBuilder<HomeAccountsBloc, HomeAccountsState>(builder: (_, state) => _HomeBody(state: state)),
    );
  }
}

final class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.state});

  final HomeAccountsState state;

  void _handleAdd(BuildContext context) => unawaited(context.pushNamed(RouteNames.newAccount));

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;
    final accountsLocale = locale.accounts;
    final accounts = state.accounts;

    if (accounts == null) {
      return switch (state) {
        HomeAccountsLoadErrorState(:final failure) => GPEmptyState(icon: const Icon(Icons.error_outline), title: failure.getMessage(locale)),
        HomeAccountsInitState() || HomeAccountsLoadingState() || HomeAccountsLoadedState() => const Center(child: CircularProgressIndicator()),
      };
    }

    if (accounts.isEmpty) {
      return GPEmptyState(
        icon: const Icon(Icons.account_balance_wallet_outlined),
        actionLabel: accountsLocale.add,
        message: accountsLocale.emptyBody,
        title: accountsLocale.emptyTitle,
        onAction: () => _handleAdd(context),
      );
    }

    final spacing = context.spacing;
    return ListView(
      // Explicit padding replaces the automatic one, so the shell's dock inset is added back by hand.
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.xs, spacing.md, spacing.md + MediaQuery.paddingOf(context).bottom),
      children: [_AccountsSection(accounts: accounts.take(HomeView.accountsShown).toList())],
    );
  }
}

final class _AccountsSection extends StatelessWidget {
  const _AccountsSection({required this.accounts});

  final List<AccountBalance> accounts;

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;
    final colors = context.colors;
    final spacing = context.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.xs,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(locale.accounts.title, style: context.text.headlineSmall.copyWith(color: colors.onBackground)),
                ),
              ),
              TextButton(
                onPressed: () => context.goNamed(RouteNames.accounts),
                style: TextButton.styleFrom(
                  foregroundColor: colors.accentInk,
                  textStyle: context.text.titleSmall.copyWith(fontWeight: FontWeight.w600),
                  minimumSize: const Size(48.0, 48.0),
                  padding: EdgeInsets.symmetric(horizontal: spacing.sm),
                ),
                child: Text(locale.home.seeAllAccounts),
              ),
            ],
          ),
        ),
        AccountBalanceCardWidget(balances: accounts),
      ],
    );
  }
}
