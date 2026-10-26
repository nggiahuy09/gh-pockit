import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/app.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/app/router/app_shell.dart';
import 'package:ghpockit/core/localization/locale.dart';

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
}
