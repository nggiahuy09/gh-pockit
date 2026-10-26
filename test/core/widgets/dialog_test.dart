import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/widgets/button.dart';
import 'package:ghpockit/core/widgets/dialog.dart';

import '../../helpers/localization_harness.dart';
import '../../helpers/widget_harness.dart';

const List<GPDialogAction<String>> _cancelAndDelete = [
  GPDialogAction.cancel(value: 'cancel', label: 'Cancel'),
  GPDialogAction(value: 'delete', variant: GPButtonVariant.danger, label: 'Delete'),
];

/// Pumps a launcher, opens the dialog and returns a box that receives its result once it closes.
Future<List<String?>> _open(WidgetTester tester, {required List<GPDialogAction<String>> actions, required GPLocalization localization}) async {
  final results = <String?>[];
  await pumpOnPhone(
    tester,
    localization: localization,
    child: Builder(
      builder: (context) => TextButton(
        onPressed: () async =>
            results.add(await showGPDialog(actions: actions, context: context, icon: Icons.delete_outline, message: 'This cannot be undone.', title: 'Delete account?')),
        child: const Text('open'),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

GPButton _button(WidgetTester tester, String label) => tester.widget<GPButton>(find.widgetWithText(GPButton, label));

void main() {
  late GPLocalization en;

  setUp(() async => en = await localizationFor(GPLocale.en));

  group('showGPDialog', () {
    testWidgets('closes with the value of the action tapped', (tester) async {
      final results = await _open(tester, actions: _cancelAndDelete, localization: en);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(results, ['delete']);
    });

    testWidgets('the scrim closes it with null', (tester) async {
      final results = await _open(
        tester,
        actions: const [GPDialogAction(value: 'ok', label: 'Got it')],
        localization: en,
      );

      await tester.tapAt(const Offset(8.0, 8.0));
      await tester.pumpAndSettle();

      expect(results, [null]);
    });

    testWidgets('two short labels sit side by side, cancel on the left', (tester) async {
      await _open(tester, actions: _cancelAndDelete, localization: en);

      final cancel = tester.getCenter(find.text('Cancel'));
      final delete = tester.getCenter(find.text('Delete'));
      expect(cancel.dy, delete.dy);
      expect(cancel.dx, lessThan(delete.dx));
    });

    testWidgets('a label too long for half the width stacks the buttons, the answer on top', (tester) async {
      await _open(
        tester,
        actions: const [
          GPDialogAction.cancel(value: 'keep', label: 'Keep editing this account'),
          GPDialogAction(value: 'discard', variant: GPButtonVariant.danger, label: 'Discard every change'),
        ],
        localization: en,
      );

      expect(tester.getCenter(find.text('Discard every change')).dy, lessThan(tester.getCenter(find.text('Keep editing this account')).dy));
    });

    testWidgets('one action spans the dialog', (tester) async {
      await _open(
        tester,
        actions: const [GPDialogAction(value: 'ok', label: 'Got it')],
        localization: en,
      );

      expect(tester.getSize(find.byType(FilledButton)).width, 294.0, reason: '390 wide, 24 margin each side, 24 padding inside');
    });

    testWidgets('focus starts on cancel when the other action destroys data, so Enter cannot delete', (tester) async {
      await _open(tester, actions: _cancelAndDelete, localization: en);

      expect(_button(tester, 'Cancel').autofocus, isTrue);
      expect(_button(tester, 'Delete').autofocus, isFalse);
    });

    testWidgets('otherwise focus starts on the action the dialog asks for', (tester) async {
      await _open(
        tester,
        actions: const [
          GPDialogAction.cancel(value: 'cancel', label: 'Cancel'),
          GPDialogAction(value: 'archive', label: 'Archive'),
        ],
        localization: en,
      );

      expect(_button(tester, 'Archive').autofocus, isTrue);
    });
  });
}
