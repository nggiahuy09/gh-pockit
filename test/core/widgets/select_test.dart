import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/widgets/field.dart';
import 'package:ghpockit/core/widgets/select.dart';

import '../../helpers/localization_harness.dart';
import '../../helpers/widget_harness.dart';

List<GPSelectOption<String>> _options(int count) => [for (var i = 0; i < count; i++) GPSelectOption(icon: Icons.category_outlined, value: 'v$i', label: 'Option $i')];

void main() {
  late GPLocalization en;

  setUp(() async => en = await localizationFor(GPLocale.en));

  group('GPSelect', () {
    testWidgets('shows the chosen option, or the placeholder when none is', (tester) async {
      await pumpOnPhone(
        tester,
        localization: en,
        child: Column(
          children: [
            GPSelect(options: _options(3), value: 'v1', label: 'Type', onChanged: (_) {}),
            GPSelect(options: _options(3), value: null, label: 'Kind', placeholder: 'Pick a type', onChanged: (_) {}),
          ],
        ),
      );

      expect(find.text('Option 1'), findsOneWidget);
      expect(find.text('Pick a type'), findsOneWidget);
    });

    testWidgets('five options or fewer open a menu under the field, not a sheet', (tester) async {
      final picked = <String>[];
      await pumpOnPhone(
        tester,
        localization: en,
        child: GPSelect(options: _options(5), value: 'v0', label: 'Type', onChanged: picked.add),
      );

      await tester.tap(find.byType(GPPickerField));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      final fieldBottom = tester.getBottomLeft(find.byType(GPFieldBox)).dy;
      expect(tester.getTopLeft(find.text('Option 0').last).dy, greaterThan(fieldBottom), reason: 'the menu must not cover the field it belongs to');

      await tester.tap(find.text('Option 3'));
      await tester.pumpAndSettle();

      expect(picked, ['v3']);
      expect(find.text('Option 4'), findsNothing, reason: 'the menu closes on a pick');
    });

    testWidgets('six options or more open a bottom sheet titled by the label', (tester) async {
      final picked = <String>[];
      await pumpOnPhone(
        tester,
        localization: en,
        child: GPSelect(options: _options(9), value: 'v0', label: 'Category', onChanged: picked.add),
      );

      await tester.tap(find.byType(GPPickerField));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Category'), findsNWidgets(2), reason: 'the field label and the sheet title');

      await tester.tap(find.text('Option 6'));
      await tester.pumpAndSettle();

      expect(picked, ['v6']);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('closing without a pick keeps the value and reports nothing', (tester) async {
      final picked = <String>[];
      await pumpOnPhone(
        tester,
        localization: en,
        child: GPSelect(options: _options(3), value: 'v0', label: 'Type', onChanged: picked.add),
      );

      await tester.tap(find.byType(GPPickerField));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(380.0, 830.0));
      await tester.pumpAndSettle();

      expect(picked, isEmpty);
      expect(find.text('Option 1'), findsNothing);
    });

    testWidgets('picking the option already chosen reports nothing', (tester) async {
      final picked = <String>[];
      await pumpOnPhone(
        tester,
        localization: en,
        child: GPSelect(options: _options(3), value: 'v0', label: 'Type', onChanged: picked.add),
      );

      await tester.tap(find.byType(GPPickerField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Option 0').last);
      await tester.pumpAndSettle();

      expect(picked, isEmpty);
    });

    testWidgets('a disabled select does not open', (tester) async {
      await pumpOnPhone(
        tester,
        localization: en,
        child: GPSelect(options: _options(3), value: 'v0', label: 'Type', onChanged: null),
      );

      await tester.tap(find.byType(GPPickerField));
      await tester.pumpAndSettle();

      expect(find.text('Option 1'), findsNothing);
    });

    testWidgets('a screen reader hears one button, named by the label, holding the value, that it can open', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpOnPhone(
        tester,
        localization: en,
        child: GPSelect(options: _options(3), value: 'v1', label: 'Type', onChanged: (_) {}),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Type')),
        matchesSemantics(label: 'Type', value: 'Option 1', isButton: true, hasEnabledState: true, isEnabled: true, hasExpandedState: true, hasTapAction: true),
      );
      semantics.dispose();
    });

    testWidgets('shows its error under the field', (tester) async {
      await pumpOnPhone(
        tester,
        localization: en,
        child: GPSelect(options: _options(3), value: null, errorText: 'Pick an account type.', label: 'Type', onChanged: (_) {}),
      );

      expect(find.text('Pick an account type.'), findsOneWidget);
    });
  });
}
