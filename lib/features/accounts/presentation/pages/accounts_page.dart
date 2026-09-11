import 'package:flutter/material.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';

/// Placeholder. The account list arrives in W4 (domain + DAO) and W5 (list UI).
class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accounts.title)),
      body: Center(child: Text(l10n.accounts.title)),
    );
  }
}
