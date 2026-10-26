import 'package:flutter/material.dart';

import '../../../../core/localization/localization_scope.dart';

final class BudgetsView extends StatelessWidget {
  const BudgetsView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewLocale = context.l10n.budgets;

    return Scaffold(
      appBar: AppBar(title: Text(viewLocale.title)),
      body: Center(child: Text(viewLocale.title)),
    );
  }
}
