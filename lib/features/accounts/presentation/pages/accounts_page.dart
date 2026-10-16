import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/error/failure_message.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/widgets/empty_state.dart';
import 'package:ghpockit/core/widgets/money_text.dart';
import 'package:ghpockit/features/accounts/presentation/account_type_label.dart';
import 'package:ghpockit/features/accounts/presentation/bloc/accounts_cubit.dart';
import 'package:go_router/go_router.dart';

/// Reads an [AccountsCubit] from the tree; the route builder provides it.
class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accounts.title),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.add), tooltip: l10n.accounts.add, onPressed: () => context.pushNamed(RouteNames.newAccount)),
        ],
      ),
      body: BlocBuilder<AccountsCubit, AccountsState>(
        builder: (BuildContext context, AccountsState state) {
          final failure = state.failure;
          final accounts = state.balances;

          // No retry button: the query stays live, so the list comes back by itself once the data does.
          if (accounts == null && failure != null) return GPEmptyState(icon: const Icon(Icons.error_outline), title: failure.message(l10n));
          if (accounts == null) return const Center(child: CircularProgressIndicator());

          if (accounts.isEmpty) {
            // Its own button rather than "tap +": the dock's + on this tab adds a transaction, not an account.
            return GPEmptyState(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              title: l10n.accounts.emptyTitle,
              message: l10n.accounts.emptyMessage,
              actionLabel: l10n.accounts.add,
              onAction: () => context.pushNamed(RouteNames.newAccount),
            );
          }

          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (BuildContext context, int index) {
              final balance = accounts[index];
              final account = balance.account;

              return ListTile(
                title: Text(account.name),
                subtitle: Text(account.type.labelIn(l10n)),
                // Neutral keeps the balance's own sign; red only repeats it for money owed.
                trailing: GPMoneyText(balance.balance, style: balance.balance.isNegative ? TextStyle(color: context.colors.expense) : null),
                onTap: () => context.pushNamed(RouteNames.editAccount, pathParameters: <String, String>{'accountId': account.id}),
              );
            },
          );
        },
      ),
    );
  }
}
