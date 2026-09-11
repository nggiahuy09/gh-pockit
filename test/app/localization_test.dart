import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/app.dart';
import 'package:ghpockit/app/router/app_shell.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/features/settings/presentation/pages/settings_page.dart';

import '../helpers/localization_harness.dart';

Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

Finder navLabel(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  group('startup language', () {
    testWidgets('renders Vietnamese throughout when the locale is vi', (WidgetTester tester) async {
      await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.vi)));
      await tester.pumpAndSettle();

      expect(navLabel('Trang chủ'), findsOneWidget);
      expect(navLabel('Giao dịch'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Trang chủ'), findsOneWidget);
    });

    testWidgets('hands the locale to Material as well, not just to our own strings', (WidgetTester tester) async {
      // Without this, `showDatePicker` month names and the Cut/Copy/Paste menu stay English while the rest of the app is Vietnamese — the gap the
      // reference project this pattern came from still has.
      await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.vi)));
      await tester.pumpAndSettle();

      expect(Localizations.localeOf(tester.element(find.byType(AppShell))).languageCode, 'vi');
      expect(MaterialLocalizations.of(tester.element(find.byType(AppShell))).cancelButtonLabel, isNot('Cancel'));
    });
  });

  group('switching language at runtime', () {
    testWidgets('repaints the shell chrome and the open page', (WidgetTester tester) async {
      await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.en)));
      await tester.pumpAndSettle();
      expect(navLabel('Home'), findsOneWidget);

      await tapTab(tester, 'Settings');
      await tester.tap(find.text('Tiếng Việt'));
      await tester.pumpAndSettle();

      // The bar belongs to the shell, the title to the page inside the branch: both must follow, or half the app stays in the old language.
      expect(navLabel('Trang chủ'), findsOneWidget);
      expect(navLabel('Home'), findsNothing);
      expect(find.widgetWithText(AppBar, 'Cài đặt'), findsOneWidget);
    });

    testWidgets('also repaints a branch that is alive but off screen', (WidgetTester tester) async {
      // The stateful shell (ADR-0003) keeps visited branches mounted. A language change must reach them too, or coming back to a tab shows the
      // previous language until something else rebuilds it.
      await tester.pumpWidget(GPApp(initialLocation: Routes.budgets, localization: await localizationFor(GPLocale.en)));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Budgets'), findsOneWidget);

      await tapTab(tester, 'Settings');
      await tester.tap(find.text('Tiếng Việt'));
      await tester.pumpAndSettle();
      await tapTab(tester, 'Ngân sách');

      expect(find.widgetWithText(AppBar, 'Ngân sách'), findsOneWidget);
    });
  });

  group('SettingsPage in isolation', () {
    testWidgets('pumps with no service locator configured', (WidgetTester tester) async {
      // The reason the scope carries the controller: a page that called `getIt` would need DI booted for a test this small.
      final localization = await localizationFor(GPLocale.en);
      await tester.pumpWidget(localizedHarness(child: const SettingsPage(), localization: localization));

      expect(find.text('Language'), findsOneWidget);
      // Every language names itself, whatever the UI language is.
      expect(find.text('English'), findsWidgets);
      expect(find.text('Tiếng Việt'), findsOneWidget);
    });

    testWidgets('a tap records the choice on the controller', (WidgetTester tester) async {
      final localization = await localizationFor(GPLocale.en);
      await tester.pumpWidget(localizedHarness(child: const SettingsPage(), localization: localization));

      await tester.tap(find.text('Tiếng Việt'));
      await tester.pumpAndSettle();

      expect(localization.locale, GPLocale.vi);
      expect(localization.isExplicit, isTrue);
      expect(find.text('Ngôn ngữ'), findsOneWidget);
    });
  });
}
