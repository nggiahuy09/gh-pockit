import 'package:flutter/material.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';

/// Placeholder for the dashboard (total balance, monthly income/expense, recent transactions — blueprint §7.1). Filled in at W6 flex, once
/// `watchAccountBalances()` exists; there is nothing to show before the aggregate queries land.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.home.title)),
      body: Center(child: Text(l10n.home.title)),
    );
  }
}
