import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/widgets/field.dart';
import 'package:ghpockit/core/widgets/text_field.dart';

import '../../helpers/localization_harness.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late GPLocalization en;

  setUp(() async => en = await localizationFor(GPLocale.en));

  BoxDecoration boxDecoration(WidgetTester tester) =>
      tester.widget<AnimatedContainer>(find.descendant(of: find.byType(GPFieldBox), matching: find.byType(AnimatedContainer))).decoration! as BoxDecoration;

  group('GPTextField', () {
    testWidgets('shows its label above the box and reports what is typed', (WidgetTester tester) async {
      final typed = <String>[];
      await pumpOnPhone(
        tester,
        localization: en,
        child: GPTextField(label: 'Name', onChanged: typed.add),
      );

      expect(find.text('Name'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Salary');

      expect(typed, <String>['Salary']);
    });

    testWidgets('an error replaces the help line and draws the danger edge', (WidgetTester tester) async {
      await pumpOnPhone(
        tester,
        localization: en,
        child: const GPTextField(label: 'Name', helperText: 'Optional.', errorText: 'Enter a name.'),
      );

      expect(find.text('Enter a name.'), findsOneWidget);
      expect(find.text('Optional.'), findsNothing);
      expect((boxDecoration(tester).border! as Border).top.width, 2);
    });

    testWidgets('focus draws the 2px edge without growing the box', (WidgetTester tester) async {
      await pumpOnPhone(
        tester,
        localization: en,
        child: const GPTextField(label: 'Name'),
      );
      final resting = tester.getSize(find.byType(GPFieldBox));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect((boxDecoration(tester).border! as Border).top.width, 2);
      expect(tester.getSize(find.byType(GPFieldBox)), resting, reason: 'a field that grows on focus shoves the whole form down by two pixels');
    });

    testWidgets('the clear button shows only while focused and not empty, and clearing reports an empty string', (WidgetTester tester) async {
      final typed = <String>[];
      await pumpOnPhone(
        tester,
        localization: en,
        child: GPTextField(label: 'Name', clearable: true, initialValue: 'Salary', onChanged: typed.add),
      );

      expect(find.byTooltip('Clear text'), findsNothing, reason: 'not focused yet');

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.tap(find.byTooltip('Clear text'));
      await tester.pump();

      expect(find.text('Salary'), findsNothing);
      expect(typed, <String>['']);
      expect(find.byTooltip('Clear text'), findsNothing);
    });

    testWidgets('maxLength counts UTF-16 units and stops typing at the cap', (WidgetTester tester) async {
      await pumpOnPhone(
        tester,
        localization: en,
        child: const GPTextField(label: 'Note', maxLength: 5),
      );

      await tester.enterText(find.byType(TextField), 'a😀bcdef');
      await tester.pump();

      // The emoji is two units: a, 😀, b, c fill the five.
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'a😀bc');
      expect(find.text('5/5'), findsOneWidget);
    });

    testWidgets('a disabled field takes no input and drops its edge', (WidgetTester tester) async {
      await pumpOnPhone(
        tester,
        localization: en,
        child: const GPTextField(label: 'Currency', initialValue: 'VND', enabled: false),
      );

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect((boxDecoration(tester).border! as Border).top.color, Colors.transparent);
    });

    testWidgets('a screen reader hears the label on the text field', (WidgetTester tester) async {
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
