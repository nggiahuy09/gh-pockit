import 'package:flutter/material.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_store.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';

/// A `GPLocalization` already resolved to [locale], with a store that touches nothing outside the test.
Future<GPLocalization> localizationFor(GPLocale locale) async {
  final localization = GPLocalization(store: GPInMemoryLocaleStore(initial: locale));
  await localization.init();
  return localization;
}

/// Wraps [child] in the minimum needed to read `context.l10n` — no app boot, no DI.
Widget localizedHarness({required Widget child, required GPLocalization localization}) => GPLocalizationScope(
  localization: localization,
  child: MaterialApp(home: child),
);
