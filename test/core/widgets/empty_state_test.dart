import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/theme/app_theme.dart';
import 'package:ghpockit/core/widgets/button.dart';
import 'package:ghpockit/core/widgets/empty_state.dart';

Widget _host(Widget child) => MaterialApp(
  theme: GPAppTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  group('GPEmptyState', () {
    testWidgets('renders the icon and title', (WidgetTester tester) async {
      await tester.pumpWidget(_host(const GPEmptyState(icon: Icon(Icons.receipt_long), title: 'No transactions yet')));

      expect(find.byIcon(Icons.receipt_long), findsOneWidget);
      expect(find.text('No transactions yet'), findsOneWidget);
    });

    testWidgets('omits the message line when there is none', (WidgetTester tester) async {
      await tester.pumpWidget(_host(const GPEmptyState(icon: Icon(Icons.receipt_long), title: 'Empty')));

      expect(find.byType(Text), findsOneWidget, reason: 'a null message must not leave an empty Text behind, which would still take vertical space');
    });

    testWidgets('renders the message when given', (WidgetTester tester) async {
      await tester.pumpWidget(_host(const GPEmptyState(icon: Icon(Icons.receipt_long), title: 'Empty', message: 'Add your first one.')));

      expect(find.text('Add your first one.'), findsOneWidget);
    });

    testWidgets('shows no button when there is no action', (WidgetTester tester) async {
      await tester.pumpWidget(_host(const GPEmptyState(icon: Icon(Icons.receipt_long), title: 'Empty')));

      expect(find.byType(GPButton), findsNothing);
    });

    testWidgets('shows the action and calls it', (WidgetTester tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(GPEmptyState(icon: const Icon(Icons.receipt_long), title: 'Empty', actionLabel: 'Add one', onAction: () => taps++)),
      );

      await tester.tap(find.text('Add one'));

      expect(taps, 1);
    });

    test('refuses a label without a handler, and a handler without a label', () {
      // A labelled button that does nothing is worse than no button: it reads as an offer and then ignores the tap. The assert makes that
      // combination impossible to construct rather than something a reviewer has to notice.
      expect(() => GPEmptyState(icon: const Icon(Icons.add), title: 'Empty', actionLabel: 'Add'), throwsAssertionError);
      expect(() => GPEmptyState(icon: const Icon(Icons.add), title: 'Empty', onAction: () {}), throwsAssertionError);
    });

    testWidgets('scrolls rather than overflowing on a short viewport', (WidgetTester tester) async {
      // A landscape phone with the keyboard up leaves very little height. A fixed Column would throw an overflow here, which in release mode is a
      // silently clipped screen.
      tester.view.physicalSize = const Size(400, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          GPEmptyState(icon: const Icon(Icons.receipt_long), title: 'Nothing here yet', message: 'A longer explanation that needs room.', actionLabel: 'Add one', onAction: () {}),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
