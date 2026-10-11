import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/money/money_formatter.dart';
import 'package:ghpockit/core/theme/colors.dart';
import 'package:ghpockit/core/widgets/money_text.dart';

import '../../helpers/localization_harness.dart';

void main() {
  final amount = Money(45000, 'VND');

  group('label', () {
    test('signs by tone, sign ahead of a leading symbol', () {
      const en = GPMoneyFormatter(GPLocale.en);

      expect(GPMoneyText.label(amount, GPMoneyTone.expense, en), '-₫45,000');
      expect(GPMoneyText.label(amount, GPMoneyTone.income, en), '+₫45,000');
      expect(GPMoneyText.label(amount, GPMoneyTone.neutral, en), '₫45,000');
    });

    test('in Vietnamese the symbol trails and the sign still leads', () {
      const vi = GPMoneyFormatter(GPLocale.vi);

      expect(GPMoneyText.label(amount, GPMoneyTone.expense, vi), startsWith('-45.000'));
      expect(GPMoneyText.label(amount, GPMoneyTone.income, vi), startsWith('+45.000'));
      expect(GPMoneyText.label(amount, GPMoneyTone.expense, vi), endsWith('₫'));
    });

    test('neutral keeps the sign of a negative amount', () {
      expect(GPMoneyText.label(Money(-45000, 'VND'), GPMoneyTone.neutral, const GPMoneyFormatter(GPLocale.en)), '-₫45,000');
    });
  });

  group('widget', () {
    Future<Text> pumpText(WidgetTester tester, GPMoneyTone tone, {TextStyle? style}) async {
      await tester.pumpWidget(
        localizedHarness(
          child: GPMoneyText(amount, tone: tone, style: style),
          localization: await localizationFor(GPLocale.en),
        ),
      );
      return tester.widget<Text>(find.byType(Text));
    }

    testWidgets('colors expense and income, leaves neutral to the caller', (WidgetTester tester) async {
      const colors = GPColors.light();

      expect((await pumpText(tester, GPMoneyTone.expense)).style!.color, colors.expense);
      expect((await pumpText(tester, GPMoneyTone.income)).style!.color, colors.income);
      expect((await pumpText(tester, GPMoneyTone.neutral, style: const TextStyle(color: Color(0xFF123456)))).style!.color, const Color(0xFF123456));
    });

    testWidgets('uses tabular figures and keeps the caller size and weight', (WidgetTester tester) async {
      final text = await pumpText(tester, GPMoneyTone.expense, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600));

      expect(text.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(text.style!.fontSize, 28);
      expect(text.style!.fontWeight, FontWeight.w600);
    });

    testWidgets('never ellipsizes', (WidgetTester tester) async {
      final text = await pumpText(tester, GPMoneyTone.income);

      expect(text.data, '+₫45,000');
      expect(text.maxLines, 1);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
    });
  });
}
