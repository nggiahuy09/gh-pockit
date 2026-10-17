import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/widgets/radio.dart';

import '../../helpers/localization_harness.dart';
import '../../helpers/widget_harness.dart';

const List<GPRadioOption<String>> _currencies = <GPRadioOption<String>>[
  GPRadioOption<String>(value: 'VND', label: 'VND (₫)', description: 'Vietnamese dong'),
  GPRadioOption<String>(value: 'USD', label: r'USD ($)', enabled: false),
  GPRadioOption<String>(value: 'EUR', label: 'EUR (€)'),
];

void main() {
  late GPLocalization en;

  setUp(() async => en = await localizationFor(GPLocale.en));

  group('GPRadio', () {
    testWidgets('a tap picks its value, through a 40 touch ring', (WidgetTester tester) async {
      final picked = <String>[];
      await pumpOnPhone(
        tester,
        localization: en,
        child: Center(
          child: GPRadio<String>(value: 'a', groupValue: 'b', onChanged: picked.add),
        ),
      );

      await tester.tap(find.byType(GPRadio<String>));

      expect(picked, <String>['a']);
      expect(tester.getSize(find.byType(GPRadioMark)), const Size(40, 40));
    });

    testWidgets('a disabled radio ignores taps', (WidgetTester tester) async {
      await pumpOnPhone(
        tester,
        localization: en,
        child: const Center(
          child: GPRadio<String>(value: 'a', groupValue: 'b', onChanged: null),
        ),
      );

      await tester.tap(find.byType(GPRadio<String>));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('GPRadioList', () {
    Future<List<String>> pump(WidgetTester tester, {String value = 'VND'}) async {
      final picked = <String>[];
      await pumpOnPhone(
        tester,
        localization: en,
        child: GPRadioList<String>(label: 'Default currency', title: 'Default currency', helperText: 'Applies at once.', options: _currencies, value: value, onChanged: picked.add),
      );
      return picked;
    }

    testWidgets('a tap anywhere on a row picks it, with no Save to press', (WidgetTester tester) async {
      final picked = await pump(tester);

      await tester.tapAt(tester.getCenter(find.text('EUR (€)')) + const Offset(150, 0));

      expect(picked, <String>['EUR']);
    });

    testWidgets('every row is at least 56 tall, and a description grows its row', (WidgetTester tester) async {
      await pump(tester);

      final rows = find.descendant(of: find.byType(GPRadioList<String>), matching: find.byType(AnimatedContainer)).evaluate().where((Element e) => e.size!.width > 300);
      expect(rows.map((Element e) => e.size!.height), everyElement(greaterThanOrEqualTo(56)));
      expect(find.text('Applies at once.'), findsOneWidget);
    });

    testWidgets('a disabled option cannot be picked', (WidgetTester tester) async {
      final picked = await pump(tester);

      await tester.tap(find.text(r'USD ($)'));

      expect(picked, isEmpty);
    });

    testWidgets('the arrow keys move the choice, stepping over a disabled option and wrapping', (WidgetTester tester) async {
      final picked = await pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(picked, <String>['EUR', 'VND'], reason: 'USD is disabled, and past EUR the choice wraps to the top');
    });

    testWidgets('each row is one radio to a screen reader, named by its label and hinted by its description', (WidgetTester tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);

      expect(
        tester.getSemantics(find.bySemanticsLabel('VND (₫)')),
        matchesSemantics(
          label: 'VND (₫)',
          hint: 'Vietnamese dong',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(r'USD ($)')),
        matchesSemantics(label: r'USD ($)', hasCheckedState: true, isInMutuallyExclusiveGroup: true, hasEnabledState: true),
      );
      semantics.dispose();
    });
  });
}
