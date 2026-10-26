import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/theme/app_theme.dart';
import 'package:ghpockit/core/widgets/form_failure_banner.dart';

Future<void> _pump(WidgetTester tester, String message) => tester.pumpWidget(
  MaterialApp(
    theme: GPAppTheme.light(),
    home: Scaffold(body: GPFormFailureBanner(message: message)),
  ),
);

void main() {
  testWidgets('shows the message, wrapping rather than cutting it', (tester) async {
    const long = 'The amount must be greater than zero, and this sentence is long enough to need a second line on a phone.';
    await _pump(tester, long);

    expect(find.text(long), findsOneWidget);
    expect(tester.widget<Text>(find.text(long)).maxLines, isNull);
  });

  testWidgets('is a live region, so a screen reader announces it while focus stays on the button', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, 'Amount must be greater than zero.');

    expect(tester.getSemantics(find.byType(GPFormFailureBanner)), containsSemantics(isLiveRegion: true));
    handle.dispose();
  });
}
