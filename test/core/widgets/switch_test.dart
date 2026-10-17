import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/widgets/switch.dart';

import '../../helpers/localization_harness.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late GPLocalization en;

  setUp(() async => en = await localizationFor(GPLocale.en));

  group('GPSwitch', () {
    testWidgets('a tap reports the opposite value', (WidgetTester tester) async {
      final changes = <bool>[];
      await pumpOnPhone(
        tester,
        localization: en,
        child: GPSwitch(value: false, onChanged: changes.add),
      );

      await tester.tap(find.byType(GPSwitch));

      expect(changes, <bool>[true]);
    });

    testWidgets('is 52×32', (WidgetTester tester) async {
      await pumpOnPhone(
        tester,
        localization: en,
        child: Center(child: GPSwitch(value: true, onChanged: (_) {})),
      );

      expect(tester.getSize(find.byType(GPSwitchTrack)), const Size(52, 32));
    });

    testWidgets('ignores taps when disabled', (WidgetTester tester) async {
      await pumpOnPhone(tester, localization: en, child: const GPSwitch(value: false, onChanged: null));

      await tester.tap(find.byType(GPSwitch));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('GPSwitchRow', () {
    testWidgets('a tap anywhere on the row toggles, not just on the switch', (WidgetTester tester) async {
      final changes = <bool>[];
      await pumpOnPhone(
        tester,
        localization: en,
        child: GPSwitchRow(title: 'This is a debt', subtitle: 'Credit card, loan', value: true, onChanged: changes.add),
      );

      await tester.tap(find.text('Credit card, loan'));

      expect(changes, <bool>[false]);
      expect(tester.getSize(find.byType(GPSwitchRow)).height, greaterThanOrEqualTo(56));
    });

    testWidgets('is one switch to a screen reader, named by its title', (WidgetTester tester) async {
      final semantics = tester.ensureSemantics();
      await pumpOnPhone(
        tester,
        localization: en,
        child: GPSwitchRow(title: 'This is a debt', value: true, onChanged: (_) {}),
      );

      expect(
        tester.getSemantics(find.byType(GPSwitchRow)),
        matchesSemantics(label: 'This is a debt', hasToggledState: true, isToggled: true, hasEnabledState: true, isEnabled: true, isFocusable: true, hasTapAction: true),
      );
      semantics.dispose();
    });
  });
}
