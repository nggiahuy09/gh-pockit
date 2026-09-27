import 'package:flutter/material.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/failure_message.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/money/money_formatter.dart';
import 'package:ghpockit/core/widgets/empty_state.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/accounts/presentation/account_type_label.dart';

/// The Accounts tab: every live, unarchived account, read straight off the Drift stream (W3 flex).
///
/// **Raw on purpose, and the rawness has an expiry date.** There is no BLoC: `flutter_bloc` is not a dependency yet and its first user is W5's
/// `TransactionBloc`, so adding it here to wrap one stream would pull that decision forward for the smallest possible reason. A `StreamBuilder` over
/// `AccountRepository.watchAccounts()` is the whole state machine a read-only list needs, and it still obeys golden rule 1: nothing here fetches, nothing
/// refreshes, and an account written anywhere appears because the stream re-emitted. The list moves behind a BLoC when it grows a filter or a form (W6).
///
/// **The repository arrives through the constructor**, resolved by the route builder in `app_router.dart`. The page never touches `getIt`, for the reason
/// `GPLocalizationScope` gives: a page that reaches into the locator cannot be pumped in a widget test without booting DI first.
///
/// **The amount shown is the opening balance**, `AccountEntity.initialBalance`. Today that is also the current balance, because no transaction can exist
/// yet. W6 T6's `watchAccountBalances()` replaces it with `initial_balance + SUM(transactions)`, in the same week the transaction form makes the two differ.
class AccountsPage extends StatefulWidget {
  const AccountsPage({required this.repository, super.key});

  final AccountRepository repository;

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  /// Subscribed once, here, and never in `build()`. A language change rebuilds this page, and a stream created in `build()` would be a new subscription
  /// every time — a flash of the loading state and a fresh query for a list that has not changed.
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
            // `AccountRepository` promises a `GPFailure` on this channel, so anything else is a bug — and ADR-0006 says a bug is not dressed up as a
            // sentence. Rethrown with its own stack trace, it reaches `FlutterError.onError` (the logger today, Sentry at P7) instead of becoming
            // "something went wrong" on a screen nobody reports.
            if (error is! GPFailure) Error.throwWithStackTrace(error, snapshot.stackTrace ?? StackTrace.current);

            // No retry button. Retrying would re-run the same query over the same rows and fail the same way; the stream is still live, so the list comes
            // back by itself as soon as the data does.
            return GPEmptyState(icon: const Icon(Icons.error_outline), title: error.message(l10n));
          }

          final accounts = snapshot.data;
          if (accounts == null) return const Center(child: CircularProgressIndicator());

          if (accounts.isEmpty) {
            return GPEmptyState(icon: const Icon(Icons.account_balance_wallet_outlined), title: l10n.accounts.emptyTitle, message: l10n.accounts.emptyMessage);
          }

          // Built per emission, which is free: the formatter is `const`-cheap and memoises its `NumberFormat`s statically.
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
