import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/theme/app_theme.dart';
import 'package:ghpockit/core/theme/colors.dart';
import 'package:ghpockit/core/widgets/button.dart';

Widget _host(Widget child) => MaterialApp(
  theme: GPAppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

/// The focus ring is the only shadow-bearing box these tests paint.
int _ringCount(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .where(
      (box) => switch (box.decoration) {
        BoxDecoration(:final boxShadow?) => boxShadow.isNotEmpty,
        _ => false,
      },
    )
    .length;

/// The inner [Material]: the [FilledButton] itself can be taller because Material pads the hit area.
double _paintedHeight(WidgetTester tester) => tester.getSize(find.descendant(of: find.byType(FilledButton), matching: find.byType(Material)).first).height;

void main() {
  group('GPButton', () {
    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(GPButton(label: 'Save', onPressed: () => taps++)));

      await tester.tap(find.text('Save'));

      expect(taps, 1);
    });

    testWidgets('a press held across frames still fires: the ring must not rebuild the button out from under the gesture', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(GPButton(label: 'Save', onPressed: () => taps++)));

      // `tap` sends down and up in one frame; a finger holds past the press timeout, the ring paints, and only then lifts.
      final gesture = await tester.startGesture(tester.getCenter(find.text('Save')));
      await tester.pump(kPressTimeout + const Duration(milliseconds: 50));
      await tester.pump();
      expect(_ringCount(tester), 1, reason: 'a pressed button paints its ring');

      await gesture.up();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(taps, 1);
    });

    testWidgets('is disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(_host(const GPButton(label: 'Save')));

      expect(tester.widget<FilledButton>(find.byType(FilledButton)).enabled, isFalse);
    });

    testWidgets('shows a spinner and refuses taps while loading', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(GPButton(label: 'Save', isLoading: true, onPressed: () => taps++)));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Save'), warnIfMissed: false);

      expect(taps, 0, reason: 'a loading button that still fires would double-submit the transaction it is already saving');
    });

    testWidgets('keeps its footprint while loading, when it has an icon to swap', (tester) async {
      await tester.pumpWidget(_host(GPButton(leading: const Icon(Icons.check), label: 'Save', onPressed: () {})));
      final restingSize = tester.getSize(find.byType(FilledButton));

      await tester.pumpWidget(_host(GPButton(leading: const Icon(Icons.check), label: 'Save', isLoading: true, onPressed: () {})));

      expect(find.text('Save'), findsOneWidget);
      expect(tester.getSize(find.byType(FilledButton)), restingSize);
    });

    testWidgets('grows by the spinner when there is no icon to swap', (tester) async {
      await tester.pumpWidget(_host(GPButton(label: 'Save', onPressed: () {})));
      final restingWidth = tester.getSize(find.byType(FilledButton)).width;

      await tester.pumpWidget(_host(GPButton(label: 'Save', isLoading: true, onPressed: () {})));

      expect(tester.getSize(find.byType(FilledButton)).width, greaterThan(restingWidth), reason: 'with no leading slot to take over, the spinner has to make room');
    });

    testWidgets('an expanded button does not move while loading', (tester) async {
      await tester.pumpWidget(_host(GPButton(label: 'Save', expanded: true, onPressed: () {})));
      final restingSize = tester.getSize(find.byType(FilledButton));

      await tester.pumpWidget(_host(GPButton(label: 'Save', expanded: true, isLoading: true, onPressed: () {})));

      expect(tester.getSize(find.byType(FilledButton)), restingSize);
    });

    testWidgets('hides the leading icon behind the spinner rather than showing both', (tester) async {
      await tester.pumpWidget(_host(GPButton(leading: const Icon(Icons.check), label: 'Save', isLoading: true, onPressed: () {})));

      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders leading and trailing icons when not loading', (tester) async {
      await tester.pumpWidget(_host(GPButton(leading: const Icon(Icons.check), trailing: const Icon(Icons.chevron_right), label: 'Save', onPressed: () {})));

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('each size paints at its documented height', (tester) async {
      for (final (size, expected) in const [(GPButtonSize.small, 40.0), (GPButtonSize.medium, 48.0), (GPButtonSize.large, 56.0)]) {
        await tester.pumpWidget(_host(GPButton(size: size, label: 'Save', onPressed: () {})));

        expect(_paintedHeight(tester), expected, reason: '$size should paint $expected tall');
      }
    });

    testWidgets('no size is ever smaller than a 48px touch target', (tester) async {
      // `small` paints at 40 and relies on Material padding the hit area to 48; `tapTargetSize: shrinkWrap` would break it.
      for (final size in GPButtonSize.values) {
        await tester.pumpWidget(_host(GPButton(size: size, label: 'Save', onPressed: () {})));

        expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48.0), reason: '$size has a sub-48 touch target');
      }
    });

    testWidgets('expanded fills the available width', (tester) async {
      await tester.pumpWidget(_host(GPButton(label: 'Save', expanded: true, onPressed: () {})));

      expect(tester.getSize(find.byType(FilledButton)).width, tester.getSize(find.byType(Scaffold)).width);
    });

    testWidgets('picks the right Material button per variant', (tester) async {
      for (final (variant, type) in const [(GPButtonVariant.outlined, OutlinedButton), (GPButtonVariant.text, TextButton), (GPButtonVariant.danger, FilledButton)]) {
        await tester.pumpWidget(_host(GPButton(variant: variant, label: 'A', onPressed: () {})));

        expect(find.byType(type), findsOneWidget, reason: '$variant should build a $type');
      }
    });

    testWidgets('a danger button is filled with the danger role, not the primary one', (tester) async {
      await tester.pumpWidget(_host(GPButton(variant: GPButtonVariant.danger, label: 'Delete', onPressed: () {})));

      final style = tester.widget<FilledButton>(find.byType(FilledButton)).style!;

      expect(style.backgroundColor!.resolve({}), const GPColors.light().danger);
    });

    testWidgets('a disabled filled button drops to the quiet surface, not a faded brand color', (tester) async {
      await tester.pumpWidget(_host(const GPButton(label: 'Save')));

      final style = tester.widget<FilledButton>(find.byType(FilledButton)).style!;

      expect(style.backgroundColor!.resolve({WidgetState.disabled}), const GPColors.light().surfaceVariant);
      expect(style.foregroundColor!.resolve({WidgetState.disabled}), const GPColors.light().onSurfaceVariant);
    });

    testWidgets('draws a focus ring once focus lands on it, and none at rest', (tester) async {
      // Focus arrives by Tab: an outer `Focus` would leave the button's own states controller untouched, and the test would pass against a broken ring.
      await tester.pumpWidget(_host(GPButton(label: 'Save', onPressed: () {})));
      await tester.pump();

      expect(_ringCount(tester), 0, reason: 'an unfocused button should not paint a ring');

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(_ringCount(tester), 1, reason: 'a focused button must paint a visible ring (WCAG 1.4.11)');
    });

    testWidgets('a disabled button never draws a ring', (tester) async {
      await tester.pumpWidget(_host(const GPButton(label: 'Save')));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(_ringCount(tester), 0);
    });

    testWidgets('survives being rebuilt into a loading state mid-frame', (tester) async {
      // Regression: Material updates its states controller during build, and a setState there tripped Flutter's '!_dirty' assertion.
      await tester.pumpWidget(_host(GPButton(label: 'Save', onPressed: () {})));
      await tester.pumpWidget(_host(GPButton(label: 'Save', isLoading: true, onPressed: () {})));
      await tester.pumpWidget(_host(GPButton(label: 'Save', onPressed: () {})));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
