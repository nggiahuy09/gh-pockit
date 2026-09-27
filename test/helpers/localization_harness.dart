import 'package:flutter/material.dart';
import 'package:ghpockit/app/theme/app_theme.dart';
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

/// Wraps [child] in the minimum a page needs — `context.l10n` and the theme extensions — with no app boot and no DI.
///
/// The theme is not optional: `context.colors` and its siblings throw under a bare `MaterialApp` by design (see `theme_context.dart`), so any page that
/// renders a `GPEmptyState` could not be pumped here without it.
Widget localizedHarness({required Widget child, required GPLocalization localization}) => GPLocalizationScope(
  localization: localization,
  child: MaterialApp(theme: GPAppTheme.light(), home: child),
);
