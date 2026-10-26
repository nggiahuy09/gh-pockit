import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../localization/locale_base/locale_base.dart';
import '../localization/localization_scope.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/dimensions.dart';
import 'button.dart';
import 'chip.dart';
import 'field.dart';
import 'sheet.dart';

/// Every date here is a local calendar day at midnight: pass `clock.nowUtc().toLocal()` as `today` and it is truncated.
DateTime _day(DateTime moment) => DateTime(moment.year, moment.month, moment.day);

DateTime _month(DateTime day) => DateTime(day.year, day.month);

final _defaultFirstDate = DateTime(2000);

/// "Today", "Yesterday", else the weekday and date, with the year only when it is not this year's. Needs the date symbols `bootstrap()` loads.
String gpDateLabel({required GPLocaleBase locale, required DateTime date, required DateTime today}) {
  final pickerLocale = locale.widgets.datePicker;
  final day = _day(date);
  final now = _day(today);
  if (day == now) return pickerLocale.today;
  if (day == DateTime(now.year, now.month, now.day - 1)) return pickerLocale.yesterday;

  return _fullDate(locale: locale, day: day, today: now);
}

String _fullDate({required GPLocaleBase locale, required DateTime day, required DateTime today}) {
  final language = locale.locale.languageCode;
  return (day.year == today.year ? DateFormat.MMMMEEEEd(language) : DateFormat.yMMMMEEEEd(language)).format(day);
}

/// Null when dismissed. No typed entry: a grid cannot be mistyped. Days after [lastDate] (today unless given) cannot be picked.
Future<DateTime?> showGPDatePicker({required BuildContext context, DateTime? firstDate, required DateTime initialDate, DateTime? lastDate, required DateTime today}) async {
  final picked = await showGPSheet<_GPCalendarResult>(
    context: context,
    title: context.l10n.widgets.datePicker.title,
    builder: (_) => _GPCalendar(
      firstDate: _day(firstDate ?? _defaultFirstDate),
      initialStart: _day(initialDate),
      lastDate: _day(lastDate ?? today),
      today: _day(today),
      isRange: false,
    ),
  );

  return picked?.start;
}

/// Null when dismissed. The range is inclusive at both ends, as calendar days.
Future<DateTimeRange?> showGPDateRangePicker({required BuildContext context, DateTimeRange? initialRange, DateTime? firstDate, DateTime? lastDate, required DateTime today}) async {
  final picked = await showGPSheet<_GPCalendarResult>(
    context: context,
    title: context.l10n.widgets.datePicker.rangeTitle,
    builder: (_) => _GPCalendar(
      firstDate: _day(firstDate ?? _defaultFirstDate),
      initialEnd: initialRange == null ? null : _day(initialRange.end),
      initialStart: initialRange == null ? null : _day(initialRange.start),
      lastDate: _day(lastDate ?? today),
      today: _day(today),
      isRange: true,
    ),
  );

  return picked == null ? null : DateTimeRange(start: picked.start, end: picked.end ?? picked.start);
}

final class GPDateField extends StatefulWidget {
  const GPDateField({super.key, this.firstDate, this.lastDate, required this.today, required this.value, this.errorText, this.helperText, this.label, required this.onChanged});

  final DateTime? firstDate;
  final DateTime? lastDate;
  final DateTime today;
  final DateTime value;
  final String? errorText;
  final String? helperText;
  final String? label;

  final void Function(DateTime day)? onChanged;

  @override
  State<GPDateField> createState() => _GPDateFieldState();
}

final class _GPDateFieldState extends State<GPDateField> {
  var _isOpen = false;

  Future<void> _handleOpen() async {
    setState(() => _isOpen = true);
    final picked = await showGPDatePicker(context: context, firstDate: widget.firstDate, initialDate: widget.value, lastDate: widget.lastDate, today: widget.today);
    if (!mounted) return;

    setState(() => _isOpen = false);
    if (picked != null && picked != _day(widget.value)) widget.onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) => GPPickerField(
    leading: Icons.calendar_today_outlined,
    errorText: widget.errorText,
    helperText: widget.helperText,
    label: widget.label,
    value: gpDateLabel(locale: context.l10n, date: widget.value, today: widget.today),
    isOpen: _isOpen,
    onTap: widget.onChanged == null ? null : _handleOpen,
  );
}

final class GPDateRangeField extends StatefulWidget {
  const GPDateRangeField({super.key, this.value, this.firstDate, this.lastDate, required this.today, this.errorText, this.helperText, this.label, required this.onChanged});

  /// Null shows the placeholder.
  final DateTimeRange? value;

  final DateTime? firstDate;
  final DateTime? lastDate;
  final DateTime today;
  final String? errorText;
  final String? helperText;
  final String? label;
  final void Function(DateTimeRange range)? onChanged;

  @override
  State<GPDateRangeField> createState() => _GPDateRangeFieldState();
}

final class _GPDateRangeFieldState extends State<GPDateRangeField> {
  var _isOpen = false;

  Future<void> _handleOpen() async {
    setState(() => _isOpen = true);
    final picked = await showGPDateRangePicker(context: context, initialRange: widget.value, firstDate: widget.firstDate, lastDate: widget.lastDate, today: widget.today);
    if (!mounted) return;

    setState(() => _isOpen = false);
    if (picked != null && picked != widget.value) widget.onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    final pickerLocale = context.l10n.widgets.datePicker;
    final value = widget.value;

    return GPPickerField(
      leading: Icons.date_range_outlined,
      errorText: widget.errorText,
      helperText: widget.helperText,
      label: widget.label,
      placeholder: pickerLocale.rangePlaceholder,
      value: value == null ? null : pickerLocale.range(end: _day(value.end), start: _day(value.start)),
      isOpen: _isOpen,
      onTap: widget.onChanged == null ? null : _handleOpen,
    );
  }
}

@immutable
final class _GPCalendarResult {
  const _GPCalendarResult({this.end, required this.start});

  final DateTime? end;
  final DateTime start;
}

final class _GPCalendar extends StatefulWidget {
  const _GPCalendar({required this.firstDate, this.initialEnd, this.initialStart, required this.lastDate, required this.today, required this.isRange});

  final DateTime firstDate;
  final DateTime? initialEnd;
  final DateTime? initialStart;
  final DateTime lastDate;
  final DateTime today;
  final bool isRange;

  @override
  State<_GPCalendar> createState() => _GPCalendarState();
}

final class _GPCalendarState extends State<_GPCalendar> {
  late DateTime? _end = widget.initialEnd;
  late DateTime? _start = widget.initialStart;
  late DateTime _visibleMonth = _month(widget.initialEnd ?? widget.initialStart ?? widget.lastDate);
  var _showsMonths = false;

  DateTime get _firstMonth => _month(widget.firstDate);

  DateTime get _lastMonth => _month(widget.lastDate);

  bool get _canGoBack => _showsMonths ? _visibleMonth.year > _firstMonth.year : _visibleMonth.isAfter(_firstMonth);

  bool get _canGoForward => _showsMonths ? _visibleMonth.year < _lastMonth.year : _visibleMonth.isBefore(_lastMonth);

  bool _isPickable(DateTime day) => !day.isBefore(widget.firstDate) && !day.isAfter(widget.lastDate);

  /// A single day picks today or yesterday when they can be picked; a range picks a whole span, clamped to the bounds.
  List<({DateTime end, String label, DateTime start})> _presetsOf(GPLocaleBaseWidgetsDatePicker pickerLocale) {
    final today = widget.today;
    if (!widget.isRange) {
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      return [
        if (_isPickable(today)) (end: today, label: pickerLocale.today, start: today),
        if (_isPickable(yesterday)) (end: yesterday, label: pickerLocale.yesterday, start: yesterday),
      ];
    }

    return [
      (end: today, label: pickerLocale.last7Days, start: DateTime(today.year, today.month, today.day - 6)),
      (end: today, label: pickerLocale.thisMonth, start: DateTime(today.year, today.month)),
      (end: DateTime(today.year, today.month, 0), label: pickerLocale.lastMonth, start: DateTime(today.year, today.month - 1)),
    ];
  }

  bool _isPresetSelected(({DateTime end, String label, DateTime start}) preset) => widget.isRange ? _start == preset.start && _end == preset.end : _start == preset.start;

  void _handlePreset(({DateTime end, String label, DateTime start}) preset) {
    if (!widget.isRange) {
      _handlePick(preset.start);
      return;
    }

    final end = preset.end.isAfter(widget.lastDate) ? widget.lastDate : preset.end;
    setState(() {
      _end = end;
      _start = preset.start.isBefore(widget.firstDate) ? widget.firstDate : preset.start;
      _visibleMonth = _month(end);
      _showsMonths = false;
    });
  }

  void _handleStep(int direction) => setState(() {
    final next = _showsMonths ? DateTime(_visibleMonth.year + direction, _visibleMonth.month) : DateTime(_visibleMonth.year, _visibleMonth.month + direction);
    // A year step can land past either end; the month grid then shows the nearest month that exists.
    _visibleMonth = next.isAfter(_lastMonth)
        ? _lastMonth
        : next.isBefore(_firstMonth)
        ? _firstMonth
        : next;
  });

  void _handlePick(DateTime day) {
    if (!widget.isRange) {
      Navigator.of(context).pop(_GPCalendarResult(start: day));
      return;
    }

    setState(() {
      final start = _start;
      if (start == null || _end != null) {
        _start = day;
        _end = null;
      } else if (day.isBefore(start)) {
        _start = day;
        _end = start;
      } else {
        _end = day;
      }
    });
  }

  void _handleMonthPick(int month) => setState(() {
    _visibleMonth = DateTime(_visibleMonth.year, month);
    _showsMonths = false;
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;
    final pickerLocale = locale.widgets.datePicker;
    final spacing = context.spacing;
    final presets = _presetsOf(pickerLocale);
    final start = _start;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: spacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (presets.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: spacing.sm),
              child: Wrap(
                spacing: spacing.sm,
                runSpacing: spacing.sm,
                children: [for (final preset in presets) GPChip(label: preset.label, selected: _isPresetSelected(preset), onPressed: () => _handlePreset(preset))],
              ),
            ),
          _GPCalendarHeader(
            label: _showsMonths ? '${_visibleMonth.year}' : pickerLocale.monthYear(month: _visibleMonth.month, year: _visibleMonth.year),
            nextLabel: _showsMonths ? pickerLocale.nextYear : pickerLocale.nextMonth,
            previousLabel: _showsMonths ? pickerLocale.previousYear : pickerLocale.previousMonth,
            semanticLabel: _showsMonths ? pickerLocale.backToDays(_visibleMonth.year) : pickerLocale.chooseMonth(month: _visibleMonth.month, year: _visibleMonth.year),
            isShowingMonths: _showsMonths,
            onNext: _canGoForward ? () => _handleStep(1) : null,
            onPrevious: _canGoBack ? () => _handleStep(-1) : null,
            onToggle: () => setState(() => _showsMonths = !_showsMonths),
          ),
          if (_showsMonths)
            _GPMonthGrid(
              pickerLocale: pickerLocale,
              firstMonth: _firstMonth,
              lastMonth: _lastMonth,
              today: widget.today,
              selectedMonth: _visibleMonth.month,
              year: _visibleMonth.year,
              onPick: _handleMonthPick,
            )
          else
            _GPDayGrid(
              weekdays: pickerLocale.weekdaysShort,
              end: widget.isRange ? _end : null,
              month: _visibleMonth,
              start: start,
              today: widget.today,
              onPick: _handlePick,
              isPickable: _isPickable,
              labelOf: (day) => _fullDate(locale: locale, day: day, today: widget.today),
            ),
          if (widget.isRange) ...[
            SizedBox(height: spacing.md),
            Text(
              start != null && _end == null ? pickerLocale.rangeEndHint : pickerLocale.rangeStartHint,
              textAlign: TextAlign.center,
              style: context.text.bodySmall.copyWith(color: context.colors.onSurfaceVariant),
            ),
            SizedBox(height: spacing.sm),
            GPButton(
              label: pickerLocale.apply,
              expanded: true,
              onPressed: start == null ? null : () => Navigator.of(context).pop(_GPCalendarResult(end: _end, start: start)),
            ),
          ],
        ],
      ),
    );
  }
}

final class _GPCalendarHeader extends StatelessWidget {
  const _GPCalendarHeader({
    required this.label,
    required this.nextLabel,
    required this.previousLabel,
    required this.semanticLabel,
    required this.isShowingMonths,
    required this.onNext,
    required this.onPrevious,
    required this.onToggle,
  });

  final String label;
  final String nextLabel;
  final String previousLabel;
  final String semanticLabel;
  final bool isShowingMonths;
  final void Function()? onNext;
  final void Function()? onPrevious;
  final void Function() onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Semantics(
          button: true,
          label: semanticLabel,
          excludeSemantics: true,
          onTap: onToggle,
          child: InkWell(
            onTap: onToggle,
            borderRadius: context.radii.borderMd,
            child: SizedBox(
              height: 48.0,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
                child: Row(
                  spacing: context.spacing.xs,
                  children: [
                    Text(
                      label,
                      style: context.text.titleMedium.copyWith(color: colors.onSurface, fontWeight: FontWeight.w600),
                    ),
                    AnimatedRotation(
                      turns: isShowingMonths ? 0.5 : 0.0,
                      duration: GPDurationTokens.normal,
                      child: Icon(Icons.expand_more, size: 20.0, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        IconButton(onPressed: onPrevious, tooltip: previousLabel, color: colors.onSurface, icon: const Icon(Icons.chevron_left)),
        IconButton(onPressed: onNext, tooltip: nextLabel, color: colors.onSurface, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

final class _GPDayGrid extends StatelessWidget {
  const _GPDayGrid({
    required this.weekdays,
    required this.end,
    required this.month,
    required this.start,
    required this.today,
    required this.onPick,
    required this.isPickable,
    required this.labelOf,
  });

  final List<String> weekdays;
  final DateTime? end;
  final DateTime month;
  final DateTime? start;
  final DateTime today;
  final void Function(DateTime day) onPick;
  final bool Function(DateTime day) isPickable;
  final String Function(DateTime day) labelOf;

  @override
  Widget build(BuildContext context) {
    // Monday first: `weekday` runs 1 (Monday) to 7.
    final leading = DateTime(month.year, month.month).weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final trailing = (7 - (leading + days) % 7) % 7;
    final cells = [for (var i = 0; i < leading; i++) null, for (var d = 1; d <= days; d++) DateTime(month.year, month.month, d), for (var i = 0; i < trailing; i++) null];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              for (final name in weekdays)
                Expanded(
                  child: SizedBox(
                    height: 32.0,
                    child: Center(
                      child: Text(name, style: context.text.labelMedium.copyWith(color: context.colors.onSurfaceVariant)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (var row = 0; row < cells.length; row += 7)
          Row(
            children: [
              for (final day in cells.sublist(row, row + 7))
                Expanded(
                  child: day == null
                      ? const SizedBox(height: 44.0)
                      : _GPDayCell(day: day, end: end, start: start, today: today, label: labelOf.call(day), isPickable: isPickable.call(day), onPick: onPick),
                ),
            ],
          ),
      ],
    );
  }
}

final class _GPDayCell extends StatelessWidget {
  const _GPDayCell({required this.day, required this.end, required this.start, required this.today, required this.label, required this.isPickable, required this.onPick});

  final DateTime day;
  final DateTime? end;
  final DateTime? start;
  final DateTime today;
  final String label;
  final bool isPickable;
  final void Function(DateTime day) onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final start = this.start;
    final end = this.end;
    final isEndpoint = day == start || day == end;
    final hasSpan = start != null && end != null && start != end;
    final isInSpan = start != null && end != null && start != end && day.isAfter(start) && day.isBefore(end);
    final isToday = day == today;
    final foreground = !isPickable
        ? colors.onSurfaceVariant
        : isEndpoint
        ? colors.onPrimary
        : isToday
        ? colors.accentInk
        : isInSpan
        ? colors.onAccentContainer
        : colors.onSurface;

    return Container(
      height: 44.0,
      // The band runs under the whole span and stops at the middle of each end's circle.
      decoration: BoxDecoration(
        color: isInSpan ? colors.accentContainer : null,
        gradient: hasSpan && isEndpoint
            ? LinearGradient(
                begin: day == start ? Alignment.centerLeft : Alignment.centerRight,
                end: day == start ? Alignment.centerRight : Alignment.centerLeft,
                colors: [Colors.transparent, Colors.transparent, colors.accentContainer, colors.accentContainer],
                stops: const [0.0, 0.5, 0.5, 1.0],
              )
            : null,
      ),
      alignment: Alignment.center,
      child: Opacity(
        opacity: isPickable ? 1.0 : 0.45,
        child: Semantics(
          button: true,
          enabled: isPickable,
          selected: isEndpoint,
          label: label,
          excludeSemantics: true,
          onTap: isPickable ? () => onPick.call(day) : null,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: isPickable ? () => onPick.call(day) : null,
              customBorder: const CircleBorder(),
              child: Container(
                width: 40.0,
                height: 40.0,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEndpoint && isPickable ? colors.primary : null,
                  border: isToday && !isEndpoint && isPickable ? Border.all(color: colors.accentInk, width: 1.5) : null,
                ),
                child: Text(
                  '${day.day}',
                  style: context.text.bodyLarge.copyWith(
                    color: foreground,
                    fontWeight: isEndpoint || isToday ? FontWeight.w600 : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _GPMonthGrid extends StatelessWidget {
  const _GPMonthGrid({
    required this.pickerLocale,
    required this.firstMonth,
    required this.lastMonth,
    required this.today,
    required this.selectedMonth,
    required this.year,
    required this.onPick,
  });

  final GPLocaleBaseWidgetsDatePicker pickerLocale;
  final DateTime firstMonth;
  final DateTime lastMonth;
  final DateTime today;
  final int selectedMonth;
  final int year;
  final void Function(int month) onPick;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.sm),
      child: GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisExtent: 48.0, crossAxisSpacing: spacing.sm, mainAxisSpacing: spacing.sm),
        children: [
          for (var month = 1; month <= 12; month++)
            _GPMonthCell(
              label: pickerLocale.monthName(month),
              isCurrent: year == today.year && month == today.month,
              isPickable: !DateTime(year, month).isBefore(firstMonth) && !DateTime(year, month).isAfter(lastMonth),
              isSelected: month == selectedMonth,
              onTap: () => onPick.call(month),
            ),
        ],
      ),
    );
  }
}

final class _GPMonthCell extends StatelessWidget {
  const _GPMonthCell({required this.label, required this.isCurrent, required this.isPickable, required this.isSelected, required this.onTap});

  final String label;
  final bool isCurrent;
  final bool isPickable;
  final bool isSelected;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = !isPickable
        ? colors.onSurfaceVariant
        : isSelected
        ? colors.onPrimary
        : isCurrent
        ? colors.accentInk
        : colors.onSurface;

    return Opacity(
      opacity: isPickable ? 1.0 : 0.45,
      child: Semantics(
        selected: isSelected,
        child: Material(
          color: isSelected && isPickable ? colors.primary : Colors.transparent,
          shape: StadiumBorder(side: isCurrent && !isSelected && isPickable ? BorderSide(color: colors.accentInk, width: 1.5) : BorderSide.none),
          child: InkWell(
            onTap: isPickable ? onTap : null,
            customBorder: const StadiumBorder(),
            child: Center(
              child: Text(
                label,
                style: context.text.bodyLarge.copyWith(color: foreground, fontWeight: isSelected || isCurrent ? FontWeight.w600 : null),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
