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
final DateTime _today = DateTime(2026, 10, 13);

void main() {
  late GPLocalization en;
  late GPLocalization vi;

  setUpAll(initializeDateFormatting);
  setUp(() async {
    en = await localizationFor(GPLocale.en);
    vi = await localizationFor(GPLocale.vi);
  });

  /// Pumps a launcher, opens the picker and returns a box that receives its result once it closes.
  Future<List<T?>> open<T>(WidgetTester tester, Future<T?> Function(BuildContext context) show, {GPLocalization? localization}) async {
    final results = <T?>[];
    await pumpOnPhone(
      tester,
      localization: localization ?? en,
      child: Builder(
        builder: (BuildContext context) => TextButton(onPressed: () async => results.add(await show(context)), child: const Text('open')),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  Finder day(String label) => find.bySemanticsLabel(label);

  group('gpDateLabel', () {
    test('names today and yesterday, and spells out any other day', () {
      final l10n = vi.current;

      expect(gpDateLabel(_today, today: _today, l10n: l10n), 'Hôm nay');
      expect(gpDateLabel(DateTime(2026, 10, 12, 23, 59), today: _today, l10n: l10n), 'Hôm qua');
      expect(gpDateLabel(DateTime(2026, 10, 8), today: _today, l10n: l10n), 'Thứ Năm, 8 tháng 10');
    });

    test('adds the year only to a day from another year', () {
      expect(gpDateLabel(DateTime(2025, 12, 31), today: _today, l10n: vi.current), contains('2025'));
      expect(gpDateLabel(DateTime(2026, 1, 2), today: _today, l10n: en.current), isNot(contains('2026')));
    });
  });

  group('showGPDatePicker', () {
    testWidgets('a tapped day is the answer, with no OK to press', (WidgetTester tester) async {
      final semantics = tester.ensureSemantics();
      final results = await open(tester, (BuildContext context) => showGPDatePicker(context: context, initialDate: _today, today: _today));

      await tester.tap(day('Thursday, October 8'));
      await tester.pumpAndSettle();

      expect(results, <DateTime?>[DateTime(2026, 10, 8)]);
      semantics.dispose();
    });

    testWidgets('a day after today cannot be picked', (WidgetTester tester) async {
      final semantics = tester.ensureSemantics();
      final results = await open(tester, (BuildContext context) => showGPDatePicker(context: context, initialDate: _today, today: _today));

      await tester.tap(day('Tuesday, October 20'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(results, isEmpty, reason: 'the sheet is still open');
      expect(
        tester.getSemantics(day('Tuesday, October 20')),
        matchesSemantics(label: 'Tuesday, October 20', isButton: true, hasEnabledState: true, hasSelectedState: true),
      );
      semantics.dispose();
    });

    testWidgets('the Yesterday chip answers at once', (WidgetTester tester) async {
      final results = await open(tester, (BuildContext context) => showGPDatePicker(context: context, initialDate: _today, today: _today));

      await tester.tap(find.text('Yesterday'));
      await tester.pumpAndSettle();

      expect(results, <DateTime?>[DateTime(2026, 10, 12)]);
    });

    testWidgets('next is off on the current month; previous steps back', (WidgetTester tester) async {
      await open(tester, (BuildContext context) => showGPDatePicker(context: context, initialDate: _today, today: _today));

      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull);

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsOneWidget);
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNotNull);
    });

    testWidgets('the month grid jumps to a month and blocks the ones still to come', (WidgetTester tester) async {
      await open(tester, (BuildContext context) => showGPDatePicker(context: context, initialDate: _today, today: _today));

      await tester.tap(find.text('October 2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('November'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('2026'), findsOneWidget, reason: 'a future month does not open');

      await tester.tap(find.text('March'));
      await tester.pumpAndSettle();

      expect(find.text('March 2026'), findsOneWidget);
    });

    testWidgets('dismissing answers null', (WidgetTester tester) async {
      final results = await open(tester, (BuildContext context) => showGPDatePicker(context: context, initialDate: _today, today: _today));

      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();

      expect(results, <DateTime?>[null]);
    });
  });

  group('showGPDateRangePicker', () {
    testWidgets('two taps in either order make the range; Apply answers it', (WidgetTester tester) async {
      final semantics = tester.ensureSemantics();
      final results = await open(tester, (BuildContext context) => showGPDateRangePicker(context: context, today: _today));

      expect(find.text('Tap a start day, then an end day'), findsOneWidget);
      await tester.tap(day('Tuesday, October 13'));
      await tester.pump();
      expect(find.text('Pick an end day'), findsOneWidget);
      await tester.tap(day('Monday, October 5'));
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(results.single, DateTimeRange(start: DateTime(2026, 10, 5), end: DateTime(2026, 10, 13)));
      semantics.dispose();
    });

    testWidgets('a preset fills the range and still waits for Apply', (WidgetTester tester) async {
      final results = await open(tester, (BuildContext context) => showGPDateRangePicker(context: context, today: _today));

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
    testWidgets('reads "Today" and reports the day picked', (WidgetTester tester) async {
      final semantics = tester.ensureSemantics();
      final picked = <DateTime>[];
      await pumpOnPhone(
        tester,
        localization: vi,
        child: GPDateField(label: 'Ngày', value: _today, today: _today, onChanged: picked.add),
      );

      expect(find.text('Hôm nay'), findsOneWidget);

      await tester.tap(find.byType(GPPickerField));
      await tester.pumpAndSettle();
      await tester.tap(day('Thứ Năm, 8 tháng 10'));
      await tester.pumpAndSettle();

      expect(picked, <DateTime>[DateTime(2026, 10, 8)]);
      semantics.dispose();
    });
  });
}
