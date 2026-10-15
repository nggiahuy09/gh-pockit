import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/widgets/button.dart';
import 'package:ghpockit/core/widgets/dialog.dart';

import '../../helpers/localization_harness.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late GPLocalization en;

  setUp(() async => en = await localizationFor(GPLocale.en));

  /// Pumps a launcher, opens the dialog and returns a box that receives its result once it closes.
  Future<List<String?>> open(WidgetTester tester, List<GPDialogAction<String>> actions) async {
    final results = <String?>[];
    await pumpOnPhone(
      tester,
      localization: en,
      child: Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () async =>
              results.add(await showGPDialog<String>(context: context, title: 'Delete account?', message: 'This cannot be undone.', icon: Icons.delete_outline, actions: actions)),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  GPButton button(WidgetTester tester, String label) => tester.widget<GPButton>(find.widgetWithText(GPButton, label));

  group('showGPDialog', () {
    testWidgets('closes with the value of the action tapped', (WidgetTester tester) async {
      final results = await open(tester, const <GPDialogAction<String>>[
        GPDialogAction<String>.cancel(label: 'Cancel', value: 'cancel'),
        GPDialogAction<String>(label: 'Delete', value: 'delete', variant: GPButtonVariant.danger),
      ]);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(results, <String?>['delete']);
    });

    testWidgets('the scrim closes it with null', (WidgetTester tester) async {
      final results = await open(tester, const <GPDialogAction<String>>[GPDialogAction<String>(label: 'Got it', value: 'ok')]);

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(results, <String?>[null]);
    });

    testWidgets('two short labels sit side by side, cancel on the left', (WidgetTester tester) async {
      await open(tester, const <GPDialogAction<String>>[
        GPDialogAction<String>.cancel(label: 'Cancel', value: 'cancel'),
        GPDialogAction<String>(label: 'Delete', value: 'delete', variant: GPButtonVariant.danger),
      ]);

      final cancel = tester.getCenter(find.text('Cancel'));
      final delete = tester.getCenter(find.text('Delete'));
      expect(cancel.dy, delete.dy);
      expect(cancel.dx, lessThan(delete.dx));
    });

    testWidgets('a label too long for half the width stacks the buttons, the answer on top', (WidgetTester tester) async {
      await open(tester, const <GPDialogAction<String>>[
        GPDialogAction<String>.cancel(label: 'Keep editing this account', value: 'keep'),
        GPDialogAction<String>(label: 'Discard every change', value: 'discard', variant: GPButtonVariant.danger),
      ]);

      expect(tester.getCenter(find.text('Discard every change')).dy, lessThan(tester.getCenter(find.text('Keep editing this account')).dy));
    });

    testWidgets('one action spans the dialog', (WidgetTester tester) async {
      await open(tester, const <GPDialogAction<String>>[GPDialogAction<String>(label: 'Got it', value: 'ok')]);

      // 390 wide, 24 margin each side, 24 padding inside: 294.
      expect(tester.getSize(find.byType(FilledButton)).width, 294);
    });

    testWidgets('focus starts on cancel when the other action destroys data, so Enter cannot delete', (WidgetTester tester) async {
      await open(tester, const <GPDialogAction<String>>[
        GPDialogAction<String>.cancel(label: 'Cancel', value: 'cancel'),
        GPDialogAction<String>(label: 'Delete', value: 'delete', variant: GPButtonVariant.danger),
      ]);

      expect(button(tester, 'Cancel').autofocus, isTrue);
      expect(button(tester, 'Delete').autofocus, isFalse);
    });

    testWidgets('otherwise focus starts on the action the dialog asks for', (WidgetTester tester) async {
      await open(tester, const <GPDialogAction<String>>[
        GPDialogAction<String>.cancel(label: 'Cancel', value: 'cancel'),
        GPDialogAction<String>(label: 'Archive', value: 'archive'),
      ]);

      expect(button(tester, 'Archive').autofocus, isTrue);
    });
  });
}
