import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';

/// Settings tab. Fills up gradually: theme (W1 flex), biometric lock and the logout wipe (W23).
///
/// The language picker is here from day one rather than at W23, because it is what makes `GPLocalization.changeLocale` reachable at all — without a
/// way to switch, the notifier and the rebuild path would be code nothing exercises.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // From the tree, not from `getIt`: a page that reaches into the locator cannot be pumped in a widget test without booting DI first.
    final localization = context.localization;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings.title)),
      body: RadioGroup<GPLocale>(
        groupValue: l10n.locale,
        onChanged: (GPLocale? selected) {
          if (selected != null) {
            // Fire and forget: the repaint is driven by the notifier, and the store write is local-only with nothing to roll back (ADR-0004).
            unawaited(localization.changeLocale(selected));
          }
        },
        child: ListView(
          children: <Widget>[
            ListTile(title: Text(l10n.settings.language), subtitle: Text(l10n.locale.displayName)),
            for (final GPLocale locale in GPLocale.values)
              // `displayName` is never translated — each language names itself, so this list reads the same whatever the current language is.
              RadioListTile<GPLocale>(title: Text(locale.displayName), value: locale),
          ],
        ),
      ),
    );
  }
}
