import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/widgets/date_picker.dart';
import 'package:ghpockit/core/widgets/field.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/localization_harness.dart';
import '../../helpers/widget_harness.dart';

/// A Tuesday, mid-month, so the grid has days on both sides of it.
final _today = DateTime(2026, 10, 13);

/// Pumps a launcher, opens the picker and returns a box that receives its result once it closes.
Future<List<T?>> _open<T>(WidgetTester tester, {required GPLocalization localization, required Future<T?> Function(BuildContext context) show}) async {
  final results = <T?>[];
  await pumpOnPhone(
    tester,
    localization: localization,
    child: Builder(
      builder: (context) => TextButton(onPressed: () async => results.add(await show.call(context)), child: const Text('open')),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

Future<DateTime?> _showDayPicker(BuildContext context) => showGPDatePicker(context: context, initialDate: _today, today: _today);

Future<DateTimeRange?> _showRangePicker(BuildContext context) => showGPDateRangePicker(context: context, today: _today);

void main() {
  late GPLocalization en;
  late GPLocalization vi;

  setUpAll(initializeDateFormatting);
  setUp(() async {
    en = await localizationFor(GPLocale.en);
    vi = await localizationFor(GPLocale.vi);
  });

  group('gpDateLabel', () {
    test('names today and yesterday, and spells out any other day', () {
      final locale = vi.current;

      expect(gpDateLabel(locale: locale, date: _today, today: _today), 'Hôm nay');
      expect(gpDateLabel(locale: locale, date: DateTime(2026, 10, 12, 23, 59), today: _today), 'Hôm qua');
      expect(gpDateLabel(locale: locale, date: DateTime(2026, 10, 8), today: _today), 'Thứ Năm, 8 tháng 10');
    });

    test('adds the year only to a day from another year', () {
      expect(gpDateLabel(locale: vi.current, date: DateTime(2025, 12, 31), today: _today), contains('2025'));
      expect(gpDateLabel(locale: en.current, date: DateTime(2026, 1, 2), today: _today), isNot(contains('2026')));
    });
  });

  group('showGPDatePicker', () {
    testWidgets('a tapped day is the answer, with no OK to press', (tester) async {
      final semantics = tester.ensureSemantics();
      final results = await _open(tester, localization: en, show: _showDayPicker);

      await tester.tap(find.bySemanticsLabel('Thursday, October 8'));
      await tester.pumpAndSettle();

      expect(results, [DateTime(2026, 10, 8)]);
      semantics.dispose();
    });

    testWidgets('a day after today cannot be picked', (tester) async {
      final semantics = tester.ensureSemantics();
      final results = await _open(tester, localization: en, show: _showDayPicker);

      await tester.tap(find.bySemanticsLabel('Tuesday, October 20'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(results, isEmpty, reason: 'the sheet is still open');
      expect(
        tester.getSemantics(find.bySemanticsLabel('Tuesday, October 20')),
        matchesSemantics(label: 'Tuesday, October 20', isButton: true, hasEnabledState: true, hasSelectedState: true),
      );
      semantics.dispose();
    });

    testWidgets('the Yesterday chip answers at once', (tester) async {
      final results = await _open(tester, localization: en, show: _showDayPicker);

      await tester.tap(find.text('Yesterday'));
      await tester.pumpAndSettle();

      expect(results, [DateTime(2026, 10, 12)]);
    });

    testWidgets('next is off on the current month; previous steps back', (tester) async {
      await _open(tester, localization: en, show: _showDayPicker);

      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull);

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsOneWidget);
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNotNull);
    });

    testWidgets('the month grid jumps to a month and blocks the ones still to come', (tester) async {
      await _open(tester, localization: en, show: _showDayPicker);

      await tester.tap(find.text('October 2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('November'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('2026'), findsOneWidget, reason: 'a future month does not open');

      await tester.tap(find.text('March'));
      await tester.pumpAndSettle();

      expect(find.text('March 2026'), findsOneWidget);
    });

    testWidgets('dismissing answers null', (tester) async {
      final results = await _open(tester, localization: en, show: _showDayPicker);

      await tester.tapAt(const Offset(195.0, 20.0));
      await tester.pumpAndSettle();

      expect(results, [null]);
    });
  });

  group('showGPDateRangePicker', () {
    testWidgets('two taps in either order make the range; Apply answers it', (tester) async {
      final semantics = tester.ensureSemantics();
      final results = await _open(tester, localization: en, show: _showRangePicker);

      expect(find.text('Tap a start day, then an end day'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Tuesday, October 13'));
      await tester.pump();
      expect(find.text('Pick an end day'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Monday, October 5'));
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(results.single, DateTimeRange(start: DateTime(2026, 10, 5), end: DateTime(2026, 10, 13)));
      semantics.dispose();
    });

    testWidgets('a preset fills the range and still waits for Apply', (tester) async {
      final results = await _open(tester, localization: en, show: _showRangePicker);

      await tester.tap(find.text('Last month'));
      await tester.pump();
      expect(results, isEmpty);
      expect(find.text('September 2026'), findsOneWidget, reason: 'the grid follows the preset');

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(results.single, DateTimeRange(start: DateTime(2026, 9), end: DateTime(2026, 9, 30)));
    });
  });

  group('GPDateField', () {
    testWidgets('reads "Today" and reports the day picked', (tester) async {
      final semantics = tester.ensureSemantics();
      final picked = <DateTime>[];
      await pumpOnPhone(
        tester,
        localization: vi,
        child: GPDateField(today: _today, value: _today, label: 'Ngày', onChanged: picked.add),
      );

      expect(find.text('Hôm nay'), findsOneWidget);

      await tester.tap(find.byType(GPPickerField));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Thứ Năm, 8 tháng 10'));
      await tester.pumpAndSettle();

      expect(picked, [DateTime(2026, 10, 8)]);
      semantics.dispose();
    });
  });
}
