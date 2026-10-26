import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/app.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/app/router/app_shell.dart';
import 'package:ghpockit/app/router/routes.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/features/settings/presentation/pages/settings_page.dart';

import '../helpers/localization_harness.dart';
import '../helpers/shell_harness.dart';

void main() {
  setUp(registerShellFakes);
  tearDown(getIt.reset);

  group('startup language', () {
    testWidgets('renders Vietnamese throughout when the locale is vi', (tester) async {
      await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.vi)));
      await tester.pumpAndSettle();

      expect(dockLabel('Trang chủ'), findsOneWidget);
      expect(dockLabel('Giao dịch'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Trang chủ'), findsOneWidget);
    });

    testWidgets('hands the locale to Material as well, not just to our own strings', (tester) async {
      await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.vi)));
      await tester.pumpAndSettle();

      expect(Localizations.localeOf(tester.element(find.byType(AppShell))).languageCode, 'vi');
      expect(MaterialLocalizations.of(tester.element(find.byType(AppShell))).cancelButtonLabel, isNot('Cancel'));
    });
  });

  group('switching language at runtime', () {
    testWidgets('repaints the shell chrome and the open page', (tester) async {
      await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.en)));
      await tester.pumpAndSettle();
      expect(dockLabel('Home'), findsOneWidget);

      await openSettings(tester);
      await tester.tap(find.text('Tiếng Việt'));
      await tester.pumpAndSettle();

      expect(dockLabel('Trang chủ'), findsOneWidget);
      expect(dockLabel('Home'), findsNothing);
      expect(find.widgetWithText(AppBar, 'Cài đặt'), findsOneWidget);
    });

    testWidgets('also repaints a branch that is alive but off screen', (tester) async {
      await tester.pumpWidget(GPApp(localization: await localizationFor(GPLocale.en), initialLocation: Routes.budgets));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Budgets'), findsOneWidget);

      await tapTab(tester, 'Home');
      await openSettings(tester);
      await tester.tap(find.text('Tiếng Việt'));
      await tester.pumpAndSettle();
      await tapTab(tester, 'Ngân sách');

      expect(find.widgetWithText(AppBar, 'Ngân sách'), findsOneWidget);
    });
  });

  group('SettingsPage in isolation', () {
    testWidgets('pumps with no service locator configured', (tester) async {
      final localization = await localizationFor(GPLocale.en);
      await tester.pumpWidget(localizedHarness(localization: localization, child: const SettingsPage()));

      expect(find.text('Language'), findsOneWidget);
      // Every language names itself, whatever the UI language is.
      expect(find.text('English'), findsWidgets);
      expect(find.text('Tiếng Việt'), findsOneWidget);
    });

    testWidgets('a tap records the choice on the controller', (tester) async {
      final localization = await localizationFor(GPLocale.en);
      await tester.pumpWidget(localizedHarness(localization: localization, child: const SettingsPage()));

      await tester.tap(find.text('Tiếng Việt'));
      await tester.pumpAndSettle();

      expect(localization.locale, GPLocale.vi);
      expect(localization.isExplicit, isTrue);
      expect(find.text('Ngôn ngữ'), findsOneWidget);
    });
  });
}
