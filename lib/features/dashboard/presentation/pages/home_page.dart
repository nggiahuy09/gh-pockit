import 'package:flutter/material.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:go_router/go_router.dart';

/// Placeholder until W6, when `watchAccountBalances()` gives the dashboard something to show.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.home.title),
        actions: <Widget>[
          IconButton(tooltip: l10n.settings.title, icon: const Icon(Icons.settings_outlined), onPressed: () => context.goNamed(RouteNames.settings)),
        ],
      ),
      body: Center(child: Text(l10n.home.title)),
    );
  }
}
