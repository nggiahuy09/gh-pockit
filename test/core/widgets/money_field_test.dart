import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/widgets/money_field.dart';

import '../../helpers/localization_harness.dart';

void main() {
  /// What the field holds after typing [typed] over [before], caret at the end as the formatter leaves it.
  String edit(GPMoneyInputFormatter formatter, String before, String typed) {
    final old = TextEditingValue(
      text: before,
      selection: TextSelection.collapsed(offset: before.length),
    );
    return formatter
        .formatEditUpdate(
          old,
          TextEditingValue(
            text: typed,
            selection: TextSelection.collapsed(offset: typed.length),
          ),
        )
        .text;
  }

  group('GPMoneyInputFormatter', () {
    final vnd = GPMoneyInputFormatter(currencyCode: 'VND', locale: GPLocale.vi);
    final usd = GPMoneyInputFormatter(currencyCode: 'USD', locale: GPLocale.en);

    test('reads the digits as minor units, so a currency with no minor unit is whole dong', () {
      expect(edit(vnd, '', '45000'), '45.000');
      expect(GPMoneyInputFormatter.minorUnitsOf('45.000'), 45000);
    });

    test('shifts digits in like a cash register: 1250 in USD is 12.50, with no separator ever parsed', () {
      expect(edit(usd, '', '1'), '0.01');
      expect(edit(usd, '0.01', '0.012'), '0.12');
      expect(edit(usd, '0.12', '0.125'), '1.25');
      expect(edit(usd, '1.25', '1.250'), '12.50');
      expect(GPMoneyInputFormatter.minorUnitsOf('12.50'), 1250);
    });

    test('backspace drops the last digit, even through a grouping separator', () {
      expect(edit(vnd, '45.000', '45.00'), '4.500');
      expect(edit(usd, '12.50', '12.5'), '1.25');
    });

    test('drops leading zeros and anything that is not a digit', () {
      expect(edit(vnd, '', '0005'), '5');
      expect(edit(vnd, '', '1a2-3'), '123');
    });

    test('an emptied field is empty, not zero', () {
      expect(edit(vnd, '5', ''), '');
      expect(edit(vnd, '5', '0'), '');
      expect(GPMoneyInputFormatter.minorUnitsOf(''), isNull);
    });

    test('refuses a digit past the cap and keeps what was there', () {
      final full = '9' * GPMoneyInputFormatter.maxDigits;
      final shown = edit(vnd, '', full);

      expect(edit(vnd, shown, '${shown}9'), shown);
    });
  });

  group('GPMoneyField', () {
    Future<List<int?>> pump(WidgetTester tester, {required String currencyCode, int? initial, GPLocale locale = GPLocale.vi}) async {
      final changes = <int?>[];
      await tester.pumpWidget(
        localizedHarness(
          localization: await localizationFor(locale),
          child: Scaffold(
            body: GPMoneyField(currencyCode: currencyCode, initialMinorUnits: initial, onChanged: changes.add),
          ),
        ),
      );
      return changes;
    }

    String shown(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).controller!.text;

    testWidgets('reports the minor units typed, and null once emptied', (WidgetTester tester) async {
      final changes = await pump(tester, currencyCode: 'VND');

      await tester.enterText(find.byType(TextField), '45000');
      await tester.enterText(find.byType(TextField), '');

      expect(changes, <int?>[45000, null]);
    });

    testWidgets('shows the initial amount in the currency it is given', (WidgetTester tester) async {
      await pump(tester, currencyCode: 'USD', initial: 1250, locale: GPLocale.en);

      expect(shown(tester), '12.50');
      expect(find.text(r'$'), findsOneWidget);
    });

    testWidgets('keeps the digits and re-reads them when the currency changes', (WidgetTester tester) async {
      final localization = await localizationFor(GPLocale.en);
      Widget field(String code) => localizedHarness(
        localization: localization,
        child: Scaffold(
          body: GPMoneyField(currencyCode: code, initialMinorUnits: 45000, onChanged: (_) {}),
        ),
      );

      await tester.pumpWidget(field('VND'));
      expect(shown(tester), '45,000');

      await tester.pumpWidget(field('USD'));
      expect(shown(tester), '450.00');
    });

    testWidgets('puts the symbol on the side the list puts it: before the digits in English, after them in Vietnamese', (WidgetTester tester) async {
      await pump(tester, currencyCode: 'VND', initial: 45000, locale: GPLocale.en);
      final english = tester.widget<TextField>(find.byType(TextField)).decoration!;
      expect((english.prefixText, english.suffixText), ('₫', null));

      await pump(tester, currencyCode: 'VND', initial: 45000);
      final vietnamese = tester.widget<TextField>(find.byType(TextField)).decoration!;
      expect((vietnamese.prefixText, vietnamese.suffixText), (null, '\u00a0₫'));
    });

    testWidgets('a tap anywhere leaves the caret at the end, so the next digit is appended rather than inserted', (WidgetTester tester) async {
      final changes = await pump(tester, currencyCode: 'VND', initial: 12500);
      final controller = tester.widget<TextField>(find.byType(TextField)).controller!;

      // Left edge of a right-aligned field: on a device this put the caret before the first digit.
      await tester.tapAt(tester.getTopLeft(find.byType(TextField)) + const Offset(8, 28));
      await tester.pump();
      expect(controller.selection, const TextSelection.collapsed(offset: 6));

      // What the platform sends for an 8 typed at that caret.
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: '12.5008', selection: TextSelection.collapsed(offset: 7)));
      await tester.pump();

      expect(shown(tester), '125.008');
      expect(changes.last, 125008);
    });

    testWidgets('a caret moved by anything else (arrow keys, a trackpad drag) snaps back to the end', (WidgetTester tester) async {
      await pump(tester, currencyCode: 'VND', initial: 12500);
      final controller = tester.widget<TextField>(find.byType(TextField)).controller!..selection = const TextSelection.collapsed(offset: 2);
      await tester.pump();

      expect(controller.selection, const TextSelection.collapsed(offset: 6));
    });

    testWidgets('re-renders what was typed when the language changes, digits kept', (WidgetTester tester) async {
      final localization = await localizationFor(GPLocale.en);
      await tester.pumpWidget(
        localizedHarness(
          localization: localization,
          child: Scaffold(
            body: GPMoneyField(currencyCode: 'USD', initialMinorUnits: 123456, onChanged: (_) {}),
          ),
        ),
      );
      expect(shown(tester), '1,234.56');

      await localization.changeLocale(GPLocale.vi);
      await tester.pump();

      expect(shown(tester), '1.234,56');
    });

    testWidgets('a tap outside puts the number pad away, since it has no Done key', (WidgetTester tester) async {
      await pump(tester, currencyCode: 'VND');
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tapAt(const Offset(10, 500));
      await tester.pump();

      expect(tester.testTextInput.isVisible, isFalse);
    });
  });
}
