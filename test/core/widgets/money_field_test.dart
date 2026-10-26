import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/widgets/money_field.dart';
import 'package:ghpockit/core/widgets/text_field.dart';

import '../../helpers/localization_harness.dart';

/// What the field holds after typing [typed] over [before], caret at the end as the formatter leaves it.
String _edit(GPMoneyInputFormatter formatter, {required String before, required String typed}) => formatter
    .formatEditUpdate(
      TextEditingValue(
        text: before,
        selection: TextSelection.collapsed(offset: before.length),
      ),
      TextEditingValue(
        text: typed,
        selection: TextSelection.collapsed(offset: typed.length),
      ),
    )
    .text;

Widget _field({required GPLocalization localization, required String currencyCode, int? initial, void Function(int? minorUnits)? onChanged}) => localizedHarness(
  localization: localization,
  child: Scaffold(
    body: GPMoneyField(currencyCode: currencyCode, initialMinorUnits: initial, onChanged: onChanged ?? (_) {}),
  ),
);

Future<List<int?>> _pump(WidgetTester tester, {GPLocale locale = GPLocale.vi, required String currencyCode, int? initial}) async {
  final changes = <int?>[];
  await tester.pumpWidget(_field(localization: await localizationFor(locale), currencyCode: currencyCode, initial: initial, onChanged: changes.add));
  return changes;
}

String _shown(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  group('GPMoneyInputFormatter', () {
    final vnd = GPMoneyInputFormatter(locale: GPLocale.vi, currencyCode: 'VND');
    final usd = GPMoneyInputFormatter(locale: GPLocale.en, currencyCode: 'USD');

    test('reads the digits as minor units, so a currency with no minor unit is whole dong', () {
      expect(_edit(vnd, before: '', typed: '45000'), '45.000');
      expect(GPMoneyInputFormatter.minorUnitsOf('45.000'), 45000);
    });

    test('shifts digits in like a cash register: 1250 in USD is 12.50, with no separator ever parsed', () {
      for (final (before, typed, expected) in const [('', '1', '0.01'), ('0.01', '0.012', '0.12'), ('0.12', '0.125', '1.25'), ('1.25', '1.250', '12.50')]) {
        expect(_edit(usd, before: before, typed: typed), expected);
      }
      expect(GPMoneyInputFormatter.minorUnitsOf('12.50'), 1250);
    });

    test('backspace drops the last digit, even through a grouping separator', () {
      expect(_edit(vnd, before: '45.000', typed: '45.00'), '4.500');
      expect(_edit(usd, before: '12.50', typed: '12.5'), '1.25');
    });

    test('drops leading zeros and anything that is not a digit', () {
      expect(_edit(vnd, before: '', typed: '0005'), '5');
      expect(_edit(vnd, before: '', typed: '1a2-3'), '123');
    });

    test('an emptied field is empty, not zero', () {
      expect(_edit(vnd, before: '5', typed: ''), '');
      expect(_edit(vnd, before: '5', typed: '0'), '');
      expect(GPMoneyInputFormatter.minorUnitsOf(''), isNull);
    });

    test('refuses a digit past the cap and keeps what was there', () {
      final shown = _edit(vnd, before: '', typed: '9' * GPMoneyInputFormatter.maxDigits);

      expect(_edit(vnd, before: shown, typed: '${shown}9'), shown);
    });
  });

  group('GPMoneyField', () {
    testWidgets('reports the minor units typed, and null once emptied', (tester) async {
      final changes = await _pump(tester, currencyCode: 'VND');

      await tester.enterText(find.byType(TextField), '45000');
      await tester.enterText(find.byType(TextField), '');

      expect(changes, [45000, null]);
    });

    testWidgets('shows the initial amount in the currency it is given', (tester) async {
      await _pump(tester, locale: GPLocale.en, currencyCode: 'USD', initial: 1250);

      expect(_shown(tester), '12.50');
      expect(find.text(r'$'), findsOneWidget);
    });

    testWidgets('keeps the digits and re-reads them when the currency changes', (tester) async {
      final localization = await localizationFor(GPLocale.en);

      await tester.pumpWidget(_field(localization: localization, currencyCode: 'VND', initial: 45000));
      expect(_shown(tester), '45,000');

      await tester.pumpWidget(_field(localization: localization, currencyCode: 'USD', initial: 45000));
      expect(_shown(tester), '450.00');
    });

    testWidgets('puts the symbol on the side the list puts it: before the digits in English, after them in Vietnamese', (tester) async {
      await _pump(tester, locale: GPLocale.en, currencyCode: 'VND', initial: 45000);
      final english = tester.widget<GPTextField>(find.byType(GPTextField));
      expect((english.prefixText, english.suffixText), ('₫', null));

      await _pump(tester, currencyCode: 'VND', initial: 45000);
      final vietnamese = tester.widget<GPTextField>(find.byType(GPTextField));
      expect((vietnamese.prefixText, vietnamese.suffixText), (null, '₫'));
    });

    testWidgets('a tap anywhere leaves the caret at the end, so the next digit is appended rather than inserted', (tester) async {
      final changes = await _pump(tester, currencyCode: 'VND', initial: 12500);
      final controller = tester.widget<TextField>(find.byType(TextField)).controller!;

      // Regression: a tap on the left edge of a right-aligned field put the caret before the first digit on a device.
      await tester.tapAt(tester.getTopLeft(find.byType(TextField)) + const Offset(8.0, 28.0));
      await tester.pump();
      expect(controller.selection, const TextSelection.collapsed(offset: 6));

      // What the platform sends for an 8 typed at that caret.
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: '12.5008', selection: TextSelection.collapsed(offset: 7)));
      await tester.pump();

      expect(_shown(tester), '125.008');
      expect(changes.last, 125008);
    });

    testWidgets('a caret moved by anything else (arrow keys, a trackpad drag) snaps back to the end', (tester) async {
      await _pump(tester, currencyCode: 'VND', initial: 12500);
      final controller = tester.widget<TextField>(find.byType(TextField)).controller!..selection = const TextSelection.collapsed(offset: 2);
      await tester.pump();

      expect(controller.selection, const TextSelection.collapsed(offset: 6));
    });

    testWidgets('re-renders what was typed when the language changes, digits kept', (tester) async {
      final localization = await localizationFor(GPLocale.en);
      await tester.pumpWidget(_field(localization: localization, currencyCode: 'USD', initial: 123456));
      expect(_shown(tester), '1,234.56');

      await localization.changeLocale(GPLocale.vi);
      await tester.pump();

      expect(_shown(tester), '1.234,56');
    });

    testWidgets('a tap outside puts the number pad away, since it has no Done key', (tester) async {
      await _pump(tester, currencyCode: 'VND');
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tapAt(const Offset(10.0, 500.0));
      await tester.pump();

      expect(tester.testTextInput.isVisible, isFalse);
    });
  });
}
