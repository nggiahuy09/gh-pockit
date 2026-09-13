import 'package:flutter/material.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';

/// Placeholder. Budgets are a Phase 6 feature (W24) — the tab exists now so the shell has its final shape and no tab has to be inserted later.
class BudgetsPage extends StatelessWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.budgets.title)),
      body: Center(child: Text(l10n.budgets.title)),
    );
  }
}
