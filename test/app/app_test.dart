import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/app.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/app/router/app_shell.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/theme/appearance.dart';
import 'package:ghpockit/core/theme/theme_preference.dart';

import '../helpers/in_memory_theme_preference_store.dart';
import '../helpers/localization_harness.dart';
import '../helpers/shell_harness.dart';

void main() {
  // Home reads the accounts on open, so the app needs repositories to land on.
  setUp(registerShellFakes);
  tearDown(getIt.reset);

  testWidgets('GPApp builds the router shell', (tester) async {
    await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.en)));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(AppShell), findsOneWidget);
  });

  group('appearance (ADR-0043)', () {
    ThemeMode modeOf(WidgetTester tester) => tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

    testWidgets('starts on the stored choice', (tester) async {
      final appearance = GPAppearance(InMemoryThemePreferenceStore(GPThemePreference.dark));
      await appearance.init();
      await tester.pumpWidget(GPApp(appearance: appearance, localization: await localizationFor(GPLocale.en)));
      await tester.pumpAndSettle();

      expect(modeOf(tester), ThemeMode.dark);
    });

    testWidgets('picking one in Settings repaints the whole app and stores it', (tester) async {
      final store = InMemoryThemePreferenceStore();
      await tester.pumpWidget(GPApp(appearance: GPAppearance(store), localization: await localizationFor(GPLocale.en)));
      await tester.pumpAndSettle();
      expect(modeOf(tester), ThemeMode.system);

      await openSettings(tester);
      await tester.ensureVisible(find.text('Dark'));
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(modeOf(tester), ThemeMode.dark);
      expect(store.stored, GPThemePreference.dark);
    });
  });
}
