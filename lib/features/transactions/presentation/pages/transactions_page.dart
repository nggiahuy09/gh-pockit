import 'package:flutter/material.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';

/// Placeholder. The transaction list arrives in W5, the create/edit flow in W6.
class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.transactions.title)),
      body: Center(child: Text(l10n.transactions.title)),
    );
  }
}
