import 'package:flutter/material.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';

/// Placeholder until W6, when `watchAccountBalances()` gives the dashboard something to show.
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
