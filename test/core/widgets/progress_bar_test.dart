import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/theme/colors.dart';
import 'package:ghpockit/core/widgets/progress_bar.dart';

import '../../helpers/localization_harness.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('GPProgressTone', () {
    GPProgressTone spending(int value, int max) => GPProgressTone.of(value: value, max: max, kind: GPProgressKind.spending);

    test('spending turns warning at 85% and over at 100%, on exact integer thresholds', () {
      expect(spending(84, 100), GPProgressTone.normal);
      expect(spending(85, 100), GPProgressTone.warning);
      expect(spending(99, 100), GPProgressTone.warning);
      expect(spending(100, 100), GPProgressTone.over);
      expect(spending(115, 100), GPProgressTone.over);
      // One dong either side of 85% of a 20M limit.
      expect(spending(17000000, 20000000), GPProgressTone.warning);
      expect(spending(16999999, 20000000), GPProgressTone.normal);
    });

    test('a goal is always the success tone, however full', () {
      expect(GPProgressTone.of(value: 0, max: 100, kind: GPProgressKind.goal), GPProgressTone.goal);
      expect(GPProgressTone.of(value: 150, max: 100, kind: GPProgressKind.goal), GPProgressTone.goal);
    });

    test('a zero limit is over as soon as anything is spent', () {
      expect(spending(0, 0), GPProgressTone.normal);
      expect(spending(1, 0), GPProgressTone.over);
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

    double fillFactor(WidgetTester tester) => tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor!;

    testWidgets('fills from empty to its share of the track', (WidgetTester tester) async {
      await pumpOnPhone(tester, localization: en, child: const GPProgressBar(value: 17, max: 100));

      expect(fillFactor(tester), 0);
      await tester.pumpAndSettle();
      expect(fillFactor(tester), closeTo(0.17, 0.0001));
    });

    testWidgets('an overspent budget fills the track, and still reads its real percentage', (WidgetTester tester) async {
      final semantics = tester.ensureSemantics();
      await pumpOnPhone(
        tester,
        localization: en,
        child: const GPProgressBar(value: 3450000, max: 3000000, semanticLabel: 'Budget'),
      );
      await tester.pumpAndSettle();

      expect(fillFactor(tester), 1);
      expect(tester.getSemantics(find.byType(GPProgressBar)), matchesSemantics(label: 'Budget', value: '115%'));
      semantics.dispose();
    });

    testWidgets('is 8 tall, or 12 large', (WidgetTester tester) async {
      await pumpOnPhone(
        tester,
        localization: en,
        child: const Column(
          children: <Widget>[
            GPProgressBar(value: 1, max: 2),
            GPProgressBar(value: 1, max: 2, size: GPProgressSize.large),
          ],
        ),
      );

      final bars = find.byType(GPProgressBar);
      expect(tester.getSize(bars.first).height, 8);
      expect(tester.getSize(bars.last).height, 12);
    });
  });
}
