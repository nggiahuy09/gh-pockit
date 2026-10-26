import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/widgets/chip.dart';

import '../../helpers/localization_harness.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late GPLocalization en;

  setUp(() async => en = await localizationFor(GPLocale.en));

  group('GPChip', () {
    testWidgets('a tap calls onPressed, and the chip is 40 tall', (tester) async {
      var taps = 0;
      await pumpOnPhone(
        tester,
        localization: en,
        child: Center(
          child: GPChip(label: 'Today', onPressed: () => taps++),
        ),
      );

      await tester.tap(find.text('Today'));

      expect(taps, 1);
      expect(tester.getSize(find.byType(AnimatedContainer)).height, 40.0);
    });

    testWidgets('a disabled chip ignores taps', (tester) async {
      var taps = 0;
      await pumpOnPhone(
        tester,
        localization: en,
        child: Center(
          child: GPChip(label: 'Next month', enabled: false, onPressed: () => taps++),
        ),
      );

      await tester.tap(find.text('Next month'));

      expect(taps, 0);
    });

    testWidgets('the remove button removes, without also pressing the chip', (tester) async {
      final semantics = tester.ensureSemantics();
      var presses = 0;
      var removals = 0;
      await pumpOnPhone(
        tester,
        localization: en,
        child: Center(
          child: GPChip(label: 'E-wallet', selected: true, onDeleted: () => removals++, onPressed: () => presses++),
        ),
      );

      await tester.tap(find.bySemanticsLabel('Remove filter E-wallet'));

      expect(removals, 1);
      expect(presses, 0);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Remove filter E-wallet')),
        matchesSemantics(label: 'Remove filter E-wallet', isButton: true, hasEnabledState: true, isEnabled: true, hasTapAction: true),
      );
      semantics.dispose();
    });

    testWidgets('tells a screen reader whether it is selected', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpOnPhone(
        tester,
        localization: en,
        child: Center(
          child: GPChip(label: 'Today', selected: true, onPressed: () {}),
        ),
      );

      expect(
        tester.getSemantics(find.text('Today')),
        matchesSemantics(
          label: 'Today',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      semantics.dispose();
    });
  });
}
