import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/money/money_formatter.dart';
import 'package:ghpockit/core/theme/colors.dart';
import 'package:ghpockit/core/widgets/money_text.dart';

import '../../helpers/localization_harness.dart';

final _amount = Money(45000, 'VND');

Future<Text> _pumpText(WidgetTester tester, {TextStyle? style, required GPMoneyTone tone}) async {
  await tester.pumpWidget(
    localizedHarness(
      localization: await localizationFor(GPLocale.en),
      child: GPMoneyText(style: style, amount: _amount, tone: tone),
    ),
  );
  return tester.widget<Text>(find.byType(Text));
}

void main() {
  group('label', () {
    test('signs by tone, sign ahead of a leading symbol', () {
      const en = GPMoneyFormatter(GPLocale.en);

      for (final (tone, expected) in const [(GPMoneyTone.expense, '-₫45,000'), (GPMoneyTone.income, '+₫45,000'), (GPMoneyTone.neutral, '₫45,000')]) {
        expect(GPMoneyText.label(_amount, en, tone), expected);
      }
    });

    test('in Vietnamese the symbol trails and the sign still leads', () {
      const vi = GPMoneyFormatter(GPLocale.vi);

      expect(GPMoneyText.label(_amount, vi, GPMoneyTone.expense), startsWith('-45.000'));
      expect(GPMoneyText.label(_amount, vi, GPMoneyTone.income), startsWith('+45.000'));
      expect(GPMoneyText.label(_amount, vi, GPMoneyTone.expense), endsWith('₫'));
    });

    test('neutral keeps the sign of a negative amount', () {
      expect(GPMoneyText.label(Money(-45000, 'VND'), const GPMoneyFormatter(GPLocale.en), GPMoneyTone.neutral), '-₫45,000');
    });
  });

  group('widget', () {
    testWidgets('colors expense and income, leaves neutral to the caller', (tester) async {
      const colors = GPColors.light();

      expect((await _pumpText(tester, tone: GPMoneyTone.expense)).style!.color, colors.expense);
      expect((await _pumpText(tester, tone: GPMoneyTone.income)).style!.color, colors.income);
      expect(
        (await _pumpText(
          tester,
          style: const TextStyle(color: Color(0xFF123456)),
          tone: GPMoneyTone.neutral,
        )).style!.color,
        const Color(0xFF123456),
      );
    });

    testWidgets('uses tabular figures and keeps the caller size and weight', (tester) async {
      final text = await _pumpText(
        tester,
        style: const TextStyle(fontSize: 28.0, fontWeight: FontWeight.w600),
        tone: GPMoneyTone.expense,
      );

      expect(text.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(text.style!.fontSize, 28.0);
      expect(text.style!.fontWeight, FontWeight.w600);
    });

    testWidgets('never ellipsizes', (tester) async {
      final text = await _pumpText(tester, tone: GPMoneyTone.income);

      expect(text.data, '+₫45,000');
      expect(text.maxLines, 1);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
    });
  });
}
