import 'package:flutter/material.dart';
import 'package:ghpockit/app/theme/app_theme.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_store.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';

Future<GPLocalization> localizationFor(GPLocale locale) async {
  final localization = GPLocalization(store: GPInMemoryLocaleStore(initial: locale));
  await localization.init();
  return localization;
}

/// No app boot, no DI. The theme is required: `context.colors` and its siblings throw under a bare `MaterialApp` (see `theme_context.dart`).
Widget localizedHarness({required Widget child, required GPLocalization localization}) => GPLocalizationScope(
  localization: localization,
  child: MaterialApp(theme: GPAppTheme.light(), home: child),
);
