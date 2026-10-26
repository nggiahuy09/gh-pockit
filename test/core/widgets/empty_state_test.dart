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
    testWidgets('renders the icon and title', (tester) async {
      await tester.pumpWidget(_host(const GPEmptyState(icon: Icon(Icons.receipt_long), title: 'No transactions yet')));

      expect(find.byIcon(Icons.receipt_long), findsOneWidget);
      expect(find.text('No transactions yet'), findsOneWidget);
    });

    testWidgets('omits the message line when there is none', (tester) async {
      await tester.pumpWidget(_host(const GPEmptyState(icon: Icon(Icons.receipt_long), title: 'Empty')));

      expect(find.byType(Text), findsOneWidget, reason: 'a null message must not leave an empty Text behind, which would still take vertical space');
    });

    testWidgets('renders the message when given', (tester) async {
      await tester.pumpWidget(_host(const GPEmptyState(icon: Icon(Icons.receipt_long), message: 'Add your first one.', title: 'Empty')));

      expect(find.text('Add your first one.'), findsOneWidget);
    });

    testWidgets('shows no button when there is no action', (tester) async {
      await tester.pumpWidget(_host(const GPEmptyState(icon: Icon(Icons.receipt_long), title: 'Empty')));

      expect(find.byType(GPButton), findsNothing);
    });

    testWidgets('shows the action and calls it', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(GPEmptyState(icon: const Icon(Icons.receipt_long), actionLabel: 'Add one', title: 'Empty', onAction: () => taps++)),
      );

      await tester.tap(find.text('Add one'));

      expect(taps, 1);
    });

    test('refuses a label without a handler, and a handler without a label', () {
      expect(() => GPEmptyState(icon: const Icon(Icons.add), actionLabel: 'Add', title: 'Empty'), throwsAssertionError);
      expect(() => GPEmptyState(icon: const Icon(Icons.add), title: 'Empty', onAction: () {}), throwsAssertionError);
    });

    testWidgets('scrolls rather than overflowing on a short viewport', (tester) async {
      tester.view
        ..physicalSize = const Size(400.0, 200.0)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          GPEmptyState(icon: const Icon(Icons.receipt_long), actionLabel: 'Add one', message: 'A longer explanation that needs room.', title: 'Nothing here yet', onAction: () {}),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
