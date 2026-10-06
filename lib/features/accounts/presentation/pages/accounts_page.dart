import 'package:flutter/material.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/failure_message.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/money/money_formatter.dart';
import 'package:ghpockit/core/widgets/empty_state.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/accounts/presentation/account_type_label.dart';

/// A bare `StreamBuilder`, no BLoC, until the list grows a filter or a form (W6). Shows the opening balance until W6 adds computed balances.
class AccountsPage extends StatefulWidget {
  const AccountsPage({required this.repository, super.key});

  final AccountRepository repository;

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  /// Created once: a stream made in `build()` would resubscribe, and flash the loading state, on every rebuild such as a language change.
  late final Stream<List<AccountEntity>> _accounts = widget.repository.watchAccounts();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accounts.title)),
      body: StreamBuilder<List<AccountEntity>>(
        stream: _accounts,
        builder: (BuildContext context, AsyncSnapshot<List<AccountEntity>> snapshot) {
          final error = snapshot.error;
          if (error != null) {
            // Anything but a `GPFailure` is a bug: rethrown to reach `FlutterError.onError`, not shown as a sentence (ADR-0006).
            if (error is! GPFailure) Error.throwWithStackTrace(error, snapshot.stackTrace ?? StackTrace.current);

            // No retry button: the stream stays live, so the list comes back by itself once the data does.
            return GPEmptyState(icon: const Icon(Icons.error_outline), title: error.message(l10n));
          }

          final accounts = snapshot.data;
          if (accounts == null) return const Center(child: CircularProgressIndicator());

          if (accounts.isEmpty) {
            return GPEmptyState(icon: const Icon(Icons.account_balance_wallet_outlined), title: l10n.accounts.emptyTitle, message: l10n.accounts.emptyMessage);
          }

          // Cheap per emission: `GPMoneyFormatter` caches its `NumberFormat`s statically.
          final formatter = GPMoneyFormatter(l10n.locale);

          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (BuildContext context, int index) {
              final account = accounts[index];

              return ListTile(
                title: Text(account.name),
                subtitle: Text(account.type.labelIn(l10n)),
                trailing: Text(formatter.format(account.initialBalance)),
              );
            },
          );
        },
      ),
    );
  }
}
