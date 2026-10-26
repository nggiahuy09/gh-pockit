import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/widgets/radio.dart';

import '../../helpers/localization_harness.dart';
import '../../helpers/widget_harness.dart';

const List<GPRadioOption<String>> _currencies = [
  GPRadioOption(value: 'VND', description: 'Vietnamese dong', label: 'VND (₫)'),
  GPRadioOption(value: 'USD', label: r'USD ($)', enabled: false),
  GPRadioOption(value: 'EUR', label: 'EUR (€)'),
];

Future<List<String>> _pumpList(WidgetTester tester, {required GPLocalization localization}) async {
  final picked = <String>[];
  await pumpOnPhone(
    tester,
    localization: localization,
    child: GPRadioList(options: _currencies, value: 'VND', helperText: 'Applies at once.', label: 'Default currency', title: 'Default currency', onChanged: picked.add),
  );
  return picked;
}

void main() {
  late GPLocalization en;

  setUp(() async => en = await localizationFor(GPLocale.en));

  group('GPRadio', () {
    testWidgets('a tap picks its value, through a 40 touch ring', (tester) async {
      final picked = <String>[];
      await pumpOnPhone(
        tester,
        localization: en,
        child: Center(
          child: GPRadio(groupValue: 'b', value: 'a', onChanged: picked.add),
        ),
      );

      await tester.tap(find.byType(GPRadio<String>));

      expect(picked, ['a']);
      expect(tester.getSize(find.byType(GPRadioMark)), const Size(40.0, 40.0));
    });

    testWidgets('a disabled radio ignores taps', (tester) async {
      await pumpOnPhone(
        tester,
        localization: en,
        child: const Center(
          child: GPRadio(groupValue: 'b', value: 'a', onChanged: null),
        ),
      );

      await tester.tap(find.byType(GPRadio<String>));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('GPRadioList', () {
    testWidgets('a tap anywhere on a row picks it, with no Save to press', (tester) async {
      final picked = await _pumpList(tester, localization: en);

      await tester.tapAt(tester.getCenter(find.text('EUR (€)')) + const Offset(150.0, 0.0));

      expect(picked, ['EUR']);
    });

    testWidgets('every row is at least 56 tall, and a description grows its row', (tester) async {
      await _pumpList(tester, localization: en);

      final rows = find.descendant(of: find.byType(GPRadioList<String>), matching: find.byType(AnimatedContainer)).evaluate().where((element) => element.size!.width > 300.0);
      expect(rows.map((element) => element.size!.height), everyElement(greaterThanOrEqualTo(56.0)));
      expect(find.text('Applies at once.'), findsOneWidget);
    });

    testWidgets('a disabled option cannot be picked', (tester) async {
      final picked = await _pumpList(tester, localization: en);

      await tester.tap(find.text(r'USD ($)'));

      expect(picked, isEmpty);
    });

    testWidgets('the arrow keys move the choice, stepping over a disabled option and wrapping', (tester) async {
      final picked = await _pumpList(tester, localization: en);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(picked, ['EUR', 'VND'], reason: 'USD is disabled, and past EUR the choice wraps to the top');
    });

    testWidgets('each row is one radio to a screen reader, named by its label and hinted by its description', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpList(tester, localization: en);

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
