import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/theme/app_theme.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';

/// A phone-sized screen with the GP theme and strings: the shared widgets read both, and sheets need the height of a real phone.
Future<void> pumpOnPhone(WidgetTester tester, {required GPLocalization localization, required Widget child, ThemeMode themeMode = ThemeMode.light}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    GPLocalizationScope(
      localization: localization,
      child: MaterialApp(
        theme: GPAppTheme.light(),
        darkTheme: GPAppTheme.dark(),
        themeMode: themeMode,
        home: Scaffold(
          body: SafeArea(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    ),
  );
}
