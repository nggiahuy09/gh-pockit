import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/theme/colors.dart';
import 'package:ghpockit/core/widgets/progress_bar.dart';

import '../../helpers/localization_harness.dart';
import '../../helpers/widget_harness.dart';

GPProgressTone _spending({required int max, required int value}) => GPProgressTone.of(kind: GPProgressKind.spending, max: max, value: value);

double _fillFactor(WidgetTester tester) => tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor!;

void main() {
  group('GPProgressTone', () {
    test('spending turns warning at 85% and over at 100%, on exact integer thresholds', () {
      for (final (value, max, expected) in const [
        (84, 100, GPProgressTone.normal),
        (85, 100, GPProgressTone.warning),
        (99, 100, GPProgressTone.warning),
        (100, 100, GPProgressTone.over),
        (115, 100, GPProgressTone.over),
        // One dong either side of 85% of a 20M limit.
        (17000000, 20000000, GPProgressTone.warning),
        (16999999, 20000000, GPProgressTone.normal),
      ]) {
        expect(
          _spending(max: max, value: value),
          expected,
          reason: '$value of $max',
        );
      }
    });

    test('a goal is always the success tone, however full', () {
      expect(GPProgressTone.of(kind: GPProgressKind.goal, max: 100, value: 0), GPProgressTone.goal);
      expect(GPProgressTone.of(kind: GPProgressKind.goal, max: 100, value: 150), GPProgressTone.goal);
    });

    test('a zero limit is over as soon as anything is spent', () {
      expect(_spending(max: 0, value: 0), GPProgressTone.normal);
      expect(_spending(max: 0, value: 1), GPProgressTone.over);
    });

    test('maps each tone to its role', () {
      const colors = GPColors.light();

      expect(GPProgressTone.normal.barColor(colors), colors.primary);
      expect(GPProgressTone.warning.barColor(colors), colors.warning);
      expect(GPProgressTone.over.barColor(colors), colors.danger);
      expect(GPProgressTone.goal.barColor(colors), colors.success);
    });
  });

  group('GPProgressBar', () {
    late GPLocalization en;

    setUp(() async => en = await localizationFor(GPLocale.en));

    testWidgets('fills from empty to its share of the track', (tester) async {
      await pumpOnPhone(tester, localization: en, child: const GPProgressBar(max: 100, value: 17));

      expect(_fillFactor(tester), 0.0);
      await tester.pumpAndSettle();
      expect(_fillFactor(tester), closeTo(0.17, 0.0001));
    });

    testWidgets('an overspent budget fills the track, and still reads its real percentage', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpOnPhone(
        tester,
        localization: en,
        child: const GPProgressBar(semanticLabel: 'Budget', max: 3000000, value: 3450000),
      );
      await tester.pumpAndSettle();

      expect(_fillFactor(tester), 1.0);
      expect(tester.getSemantics(find.byType(GPProgressBar)), matchesSemantics(label: 'Budget', value: '115%'));
      semantics.dispose();
    });

    testWidgets('is 8 tall, or 12 large', (tester) async {
      await pumpOnPhone(
        tester,
        localization: en,
        child: const Column(
          children: [
            GPProgressBar(max: 2, value: 1),
            GPProgressBar(size: GPProgressSize.large, max: 2, value: 1),
          ],
        ),
      );

      final bars = find.byType(GPProgressBar);
      expect(tester.getSize(bars.first).height, 8.0);
      expect(tester.getSize(bars.last).height, 12.0);
    });
  });
}
