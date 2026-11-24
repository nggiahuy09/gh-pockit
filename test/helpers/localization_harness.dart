import 'package:flutter/material.dart';
import 'package:ghpockit/app/theme/app_theme.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/appearance.dart';
import 'package:ghpockit/core/theme/appearance_scope.dart';

import 'in_memory_locale_store.dart';
import 'in_memory_theme_preference_store.dart';

Future<GPLocalization> localizationFor(GPLocale locale) async {
  final localization = GPLocalization(InMemoryLocaleStore(locale));
  await localization.init();
  return localization;
}

/// No app boot, no DI. The theme is required: `context.colors` and its siblings throw under a bare `MaterialApp`.
Widget localizedHarness({required GPLocalization localization, required Widget child, GPAppearance? appearance}) => GPLocalizationScope(
  localization: localization,
  child: GPAppearanceScope(
    appearance: appearance ?? GPAppearance(InMemoryThemePreferenceStore()),
    child: MaterialApp(theme: GPAppTheme.light(), home: child),
  ),
);
