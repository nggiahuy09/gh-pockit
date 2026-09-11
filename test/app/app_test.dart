import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/app.dart';
import 'package:ghpockit/app/router/app_shell.dart';

void main() {
  testWidgets('GPApp builds the router shell', (WidgetTester tester) async {
    await tester.pumpWidget(const GPApp());
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(AppShell), findsOneWidget);
  });
}
