import 'package:flutter/material.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/widgets/empty_state.dart';

/// Placeholder behind the dock's add button until the create form lands in W6.
class AddTransactionPage extends StatelessWidget {
  const AddTransactionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.transactions.add)),
      body: GPEmptyState(icon: const Icon(Icons.edit_note), title: l10n.transactions.addComingSoon),
    );
  }
}
