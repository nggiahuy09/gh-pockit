import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // From the tree, not `getIt`, so the page pumps in a widget test without DI.
    final localization = context.localization;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings.title)),
      body: RadioGroup<GPLocale>(
        groupValue: l10n.locale,
        onChanged: (GPLocale? selected) {
          if (selected != null) {
            // Fire and forget: the notifier drives the repaint, and a local-only write has nothing to roll back (ADR-0004).
            unawaited(localization.changeLocale(selected));
          }
        },
        child: ListView(
          children: <Widget>[
            ListTile(title: Text(l10n.settings.language), subtitle: Text(l10n.locale.displayName)),
            for (final GPLocale locale in GPLocale.values)
              // Untranslated on purpose: each language names itself.
              RadioListTile<GPLocale>(title: Text(locale.displayName), value: locale),
          ],
        ),
      ),
    );
  }
}
