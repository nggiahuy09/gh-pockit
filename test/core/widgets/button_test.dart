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

/// How many shadow-bearing boxes the tree holds. The button paints its focus ring as one, and nothing else in these tests paints any.
int _ringCount(WidgetTester tester) =>
    tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).where((DecoratedBox box) => (box.decoration as BoxDecoration).boxShadow?.isNotEmpty ?? false).length;

/// The painted height of the button, which is the inner [Material] — the [FilledButton] itself can be taller because Material pads the hit area.
double _paintedHeight(WidgetTester tester) => tester.getSize(find.descendant(of: find.byType(FilledButton), matching: find.byType(Material)).first).height;

void main() {
  group('GPButton', () {
    testWidgets('calls onPressed when tapped', (WidgetTester tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(GPButton(label: 'Save', onPressed: () => taps++)));

      await tester.tap(find.text('Save'));

      expect(taps, 1);
    });

    testWidgets('is disabled when onPressed is null', (WidgetTester tester) async {
      await tester.pumpWidget(_host(const GPButton(label: 'Save')));

      expect(tester.widget<FilledButton>(find.byType(FilledButton)).enabled, isFalse);
    });

    testWidgets('shows a spinner and refuses taps while loading', (WidgetTester tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(GPButton(label: 'Save', isLoading: true, onPressed: () => taps++)));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Save'), warnIfMissed: false);

      expect(taps, 0, reason: 'a loading button that still fires would double-submit the transaction it is already saving');
    });

    testWidgets('keeps its footprint while loading, when it has an icon to swap', (WidgetTester tester) async {
      // The spinner takes over the leading slot, so nothing moves. This is the case a form's submit button is in.
      await tester.pumpWidget(_host(GPButton(label: 'Save', leading: const Icon(Icons.check), onPressed: () {})));
      final restingSize = tester.getSize(find.byType(FilledButton));

      await tester.pumpWidget(_host(GPButton(label: 'Save', leading: const Icon(Icons.check), isLoading: true, onPressed: () {})));

      expect(find.text('Save'), findsOneWidget);
      expect(tester.getSize(find.byType(FilledButton)), restingSize);
    });

    testWidgets('grows by the spinner when there is no icon to swap', (WidgetTester tester) async {
      // Documented, not accidental: with no leading slot to take over, the spinner has to make room. Asserting it means a future change to that
      // behaviour has to be a deliberate one rather than a surprise.
      await tester.pumpWidget(_host(GPButton(label: 'Save', onPressed: () {})));
      final restingWidth = tester.getSize(find.byType(FilledButton)).width;

      await tester.pumpWidget(_host(GPButton(label: 'Save', isLoading: true, onPressed: () {})));

      expect(tester.getSize(find.byType(FilledButton)).width, greaterThan(restingWidth));
    });

    testWidgets('an expanded button does not move while loading', (WidgetTester tester) async {
      // Which is the answer to the test above, and the reason the doc tells form submits to be expanded.
      await tester.pumpWidget(_host(GPButton(label: 'Save', expanded: true, onPressed: () {})));
      final restingSize = tester.getSize(find.byType(FilledButton));

      await tester.pumpWidget(_host(GPButton(label: 'Save', expanded: true, isLoading: true, onPressed: () {})));

      expect(tester.getSize(find.byType(FilledButton)), restingSize);
    });

    testWidgets('hides the leading icon behind the spinner rather than showing both', (WidgetTester tester) async {
      await tester.pumpWidget(_host(GPButton(label: 'Save', leading: const Icon(Icons.check), isLoading: true, onPressed: () {})));

      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders leading and trailing icons when not loading', (WidgetTester tester) async {
      await tester.pumpWidget(_host(GPButton(label: 'Save', leading: const Icon(Icons.check), trailing: const Icon(Icons.chevron_right), onPressed: () {})));

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('each size paints at its documented height', (WidgetTester tester) async {
      for (final (GPButtonSize size, double expected) in <(GPButtonSize, double)>[(GPButtonSize.small, 40), (GPButtonSize.medium, 48), (GPButtonSize.large, 56)]) {
        await tester.pumpWidget(_host(GPButton(label: 'Save', size: size, onPressed: () {})));

        expect(_paintedHeight(tester), expected, reason: '$size should paint $expected tall');
      }
    });

    testWidgets('no size is ever smaller than a 48px touch target', (WidgetTester tester) async {
      // `small` paints at 40, and Material pads its hit area back to 48. That padding is the only reason a 40px button is allowed to exist; if a
      // future style change sets `tapTargetSize: shrinkWrap` to reclaim the space, this catches the accessibility regression.
      for (final size in GPButtonSize.values) {
        await tester.pumpWidget(_host(GPButton(label: 'Save', size: size, onPressed: () {})));

        expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48), reason: '$size has a sub-48 touch target');
      }
    });

    testWidgets('expanded fills the available width', (WidgetTester tester) async {
      await tester.pumpWidget(_host(GPButton(label: 'Save', expanded: true, onPressed: () {})));

      expect(tester.getSize(find.byType(FilledButton)).width, tester.getSize(find.byType(Scaffold)).width);
    });

    testWidgets('picks the right Material button per variant', (WidgetTester tester) async {
      // Not cosmetic: OutlinedButton and TextButton bring their own minimum sizes and overlay behaviour, and a filled variant rendered as a
      // TextButton would silently lose its background.
      await tester.pumpWidget(_host(GPButton(label: 'A', variant: GPButtonVariant.outlined, onPressed: () {})));
      expect(find.byType(OutlinedButton), findsOneWidget);

      await tester.pumpWidget(_host(GPButton(label: 'A', variant: GPButtonVariant.text, onPressed: () {})));
      expect(find.byType(TextButton), findsOneWidget);

      await tester.pumpWidget(_host(GPButton(label: 'A', variant: GPButtonVariant.danger, onPressed: () {})));
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('a danger button is filled with the danger role, not the primary one', (WidgetTester tester) async {
      await tester.pumpWidget(_host(GPButton(label: 'Delete', variant: GPButtonVariant.danger, onPressed: () {})));

      final style = tester.widget<FilledButton>(find.byType(FilledButton)).style!;

      expect(style.backgroundColor!.resolve(<WidgetState>{}), const GPColors.light().danger);
    });

    testWidgets('a disabled filled button drops to the quiet surface, not a faded brand color', (WidgetTester tester) async {
      await tester.pumpWidget(_host(const GPButton(label: 'Save')));

      final style = tester.widget<FilledButton>(find.byType(FilledButton)).style!;

      expect(style.backgroundColor!.resolve(<WidgetState>{WidgetState.disabled}), const GPColors.light().surfaceVariant);
      expect(style.foregroundColor!.resolve(<WidgetState>{WidgetState.disabled}), const GPColors.light().onSurfaceVariant);
    });

    testWidgets('draws a focus ring once focus lands on it, and none at rest', (WidgetTester tester) async {
      // Focus arrives by Tab, not by wrapping the button in an outer `Focus`: the ring reads the button's *own* states controller, and an outer
      // focus node would leave that controller untouched — the test would then pass against a broken widget.
      //
      // The ring is the reason this widget is stateful at all. If the states listener stops firing, this is what notices.
      await tester.pumpWidget(_host(GPButton(label: 'Save', onPressed: () {})));
      await tester.pump();

      expect(_ringCount(tester), 0, reason: 'an unfocused button should not paint a ring');

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(_ringCount(tester), 1, reason: 'a focused button must paint a visible ring — WCAG 1.4.11');
    });

    testWidgets('a disabled button never draws a ring', (WidgetTester tester) async {
      await tester.pumpWidget(_host(const GPButton(label: 'Save')));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(_ringCount(tester), 0);
    });

    testWidgets('survives being rebuilt into a loading state mid-frame', (WidgetTester tester) async {
      // The regression this guards: the Material button updates its states controller during build, which used to fire setState inside a build and
      // trip Flutter's '!_dirty' assertion. Toggling isLoading is exactly the path that triggers it.
      await tester.pumpWidget(_host(GPButton(label: 'Save', onPressed: () {})));
      await tester.pumpWidget(_host(GPButton(label: 'Save', isLoading: true, onPressed: () {})));
      await tester.pumpWidget(_host(GPButton(label: 'Save', onPressed: () {})));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
