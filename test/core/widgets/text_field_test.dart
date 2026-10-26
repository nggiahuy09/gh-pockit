import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/widgets/field.dart';
import 'package:ghpockit/core/widgets/text_field.dart';

import '../../helpers/localization_harness.dart';
import '../../helpers/widget_harness.dart';

Border _boxBorder(WidgetTester tester) =>
    switch (tester.widget<AnimatedContainer>(find.descendant(of: find.byType(GPFieldBox), matching: find.byType(AnimatedContainer))).decoration) {
      BoxDecoration(border: final Border border) => border,
      final decoration => throw TestFailure('Expected a BoxDecoration with a Border, got $decoration'),
    };

void main() {
  late GPLocalization en;

  setUp(() async => en = await localizationFor(GPLocale.en));

  group('GPTextField', () {
    testWidgets('shows its label above the box and reports what is typed', (tester) async {
      final typed = <String>[];
      await pumpOnPhone(
        tester,
        localization: en,
        child: GPTextField(label: 'Name', onChanged: typed.add),
      );

      expect(find.text('Name'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Salary');

      expect(typed, ['Salary']);
    });

    testWidgets('an error replaces the help line and draws the danger edge', (tester) async {
      await pumpOnPhone(
        tester,
        localization: en,
        child: const GPTextField(errorText: 'Enter a name.', helperText: 'Optional.', label: 'Name'),
      );

      expect(find.text('Enter a name.'), findsOneWidget);
      expect(find.text('Optional.'), findsNothing);
      expect(_boxBorder(tester).top.width, 2.0);
    });

    testWidgets('focus draws the 2px edge without growing the box', (tester) async {
      await pumpOnPhone(
        tester,
        localization: en,
        child: const GPTextField(label: 'Name'),
      );
      final resting = tester.getSize(find.byType(GPFieldBox));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(_boxBorder(tester).top.width, 2.0);
      expect(tester.getSize(find.byType(GPFieldBox)), resting, reason: 'a field that grows on focus shoves the whole form down by two pixels');
    });

    testWidgets('the clear button shows only while focused and not empty, and clearing reports an empty string', (tester) async {
      final typed = <String>[];
      await pumpOnPhone(
        tester,
        localization: en,
        child: GPTextField(initialValue: 'Salary', label: 'Name', clearable: true, onChanged: typed.add),
      );

      expect(find.byTooltip('Clear text'), findsNothing, reason: 'not focused yet');

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.tap(find.byTooltip('Clear text'));
      await tester.pump();

      expect(find.text('Salary'), findsNothing);
      expect(typed, ['']);
      expect(find.byTooltip('Clear text'), findsNothing);
    });

    testWidgets('maxLength counts UTF-16 units and stops typing at the cap', (tester) async {
      await pumpOnPhone(
        tester,
        localization: en,
        child: const GPTextField(label: 'Note', maxLength: 5),
      );

      await tester.enterText(find.byType(TextField), 'a😀bcdef');
      await tester.pump();

      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'a😀bc', reason: 'the emoji is two units: a, 😀, b, c fill the five');
      expect(find.text('5/5'), findsOneWidget);
    });

    testWidgets('a disabled field takes no input and drops its edge', (tester) async {
      await pumpOnPhone(
        tester,
        localization: en,
        child: const GPTextField(initialValue: 'VND', label: 'Currency', enabled: false),
      );

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(_boxBorder(tester).top.color, Colors.transparent);
    });

    testWidgets('a screen reader hears the label on the text field', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpOnPhone(
        tester,
        localization: en,
        child: const GPTextField(label: 'Name'),
      );

      expect(find.bySemanticsLabel(RegExp('Name')), findsOneWidget);
      semantics.dispose();
    });
  });
}
