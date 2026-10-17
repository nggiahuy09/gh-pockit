import 'package:flutter/material.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/theme/tokens/dimensions.dart';
import 'package:ghpockit/core/widgets/button.dart';
import 'package:ghpockit/core/widgets/chip.dart';
import 'package:ghpockit/core/widgets/field.dart';
import 'package:ghpockit/core/widgets/sheet.dart';
import 'package:intl/intl.dart';

/// Every date here is a local calendar day at midnight: pass `clock.nowUtc().toLocal()` as `today` and it is truncated.
DateTime _day(DateTime moment) => DateTime(moment.year, moment.month, moment.day);

DateTime _month(DateTime day) => DateTime(day.year, day.month);

final DateTime _defaultFirstDate = DateTime(2000);

/// "Today", "Yesterday", else the weekday and date, with the year only when it is not this year's. Needs the date symbols `bootstrap()` loads.
String gpDateLabel(DateTime date, {required DateTime today, required GPLocaleBase l10n}) {
  final day = _day(date);
  final now = _day(today);
  if (day == now) return l10n.widgets.datePicker.today;
  if (day == DateTime(now.year, now.month, now.day - 1)) return l10n.widgets.datePicker.yesterday;
  return _fullDate(day, today: now, l10n: l10n);
}

String _fullDate(DateTime day, {required DateTime today, required GPLocaleBase l10n}) {
  final language = l10n.locale.languageCode;
  return (day.year == today.year ? DateFormat.MMMMEEEEd(language) : DateFormat.yMMMMEEEEd(language)).format(day);
}

/// Null when dismissed. No typed entry: a grid cannot be mistyped. Days after [lastDate] (today unless given) cannot be picked.
Future<DateTime?> showGPDatePicker({required BuildContext context, required DateTime initialDate, required DateTime today, DateTime? firstDate, DateTime? lastDate}) async {
  final picked = await showGPSheet<_GPCalendarResult>(
    context: context,
    title: context.l10n.widgets.datePicker.title,
    builder: (BuildContext context) => _GPCalendar(
      isRange: false,
      today: _day(today),
      firstDate: _day(firstDate ?? _defaultFirstDate),
      lastDate: _day(lastDate ?? today),
      initialStart: _day(initialDate),
    ),
  );
  return picked?.start;
}

/// Null when dismissed. The range is inclusive at both ends, as calendar days.
Future<DateTimeRange?> showGPDateRangePicker({required BuildContext context, required DateTime today, DateTimeRange? initialRange, DateTime? firstDate, DateTime? lastDate}) async {
  final picked = await showGPSheet<_GPCalendarResult>(
    context: context,
    title: context.l10n.widgets.datePicker.rangeTitle,
    builder: (BuildContext context) => _GPCalendar(
      isRange: true,
      today: _day(today),
      firstDate: _day(firstDate ?? _defaultFirstDate),
      lastDate: _day(lastDate ?? today),
      initialStart: initialRange == null ? null : _day(initialRange.start),
      initialEnd: initialRange == null ? null : _day(initialRange.end),
    ),
  );
  return picked == null ? null : DateTimeRange(start: picked.start, end: picked.end ?? picked.start);
}

class GPDateField extends StatefulWidget {
  const GPDateField({required this.value, required this.today, required this.onChanged, this.label, this.firstDate, this.lastDate, this.helperText, this.errorText, super.key});

  final DateTime value;
  final DateTime today;

  /// Null disables the field.
  final ValueChanged<DateTime>? onChanged;

  final String? label;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? helperText;
  final String? errorText;

  @override
  State<GPDateField> createState() => _GPDateFieldState();
}

class _GPDateFieldState extends State<GPDateField> {
  bool _isOpen = false;

  Future<void> _open() async {
    setState(() => _isOpen = true);
    final picked = await showGPDatePicker(context: context, initialDate: widget.value, today: widget.today, firstDate: widget.firstDate, lastDate: widget.lastDate);
    if (!mounted) return;

    setState(() => _isOpen = false);
    if (picked != null && picked != _day(widget.value)) widget.onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) => GPPickerField(
    onTap: widget.onChanged == null ? null : _open,
    label: widget.label,
    value: gpDateLabel(widget.value, today: widget.today, l10n: context.l10n),
    leading: Icons.calendar_today_outlined,
    isOpen: _isOpen,
    helperText: widget.helperText,
    errorText: widget.errorText,
  );
}

class GPDateRangeField extends StatefulWidget {
  const GPDateRangeField({
    required this.value,
    required this.today,
    required this.onChanged,
    this.label,
    this.firstDate,
    this.lastDate,
    this.helperText,
    this.errorText,
    super.key,
  });

  /// Null shows the placeholder.
  final DateTimeRange? value;
  final DateTime today;
  final ValueChanged<DateTimeRange>? onChanged;
  final String? label;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? helperText;
  final String? errorText;

  @override
  State<GPDateRangeField> createState() => _GPDateRangeFieldState();
}

class _GPDateRangeFieldState extends State<GPDateRangeField> {
  bool _isOpen = false;

  Future<void> _open() async {
    setState(() => _isOpen = true);
    final picked = await showGPDateRangePicker(context: context, today: widget.today, initialRange: widget.value, firstDate: widget.firstDate, lastDate: widget.lastDate);
    if (!mounted) return;

    setState(() => _isOpen = false);
    if (picked != null && picked != widget.value) widget.onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.widgets.datePicker;
    final value = widget.value;

    return GPPickerField(
      onTap: widget.onChanged == null ? null : _open,
      label: widget.label,
      value: value == null ? null : strings.range(_day(value.start), _day(value.end)),
      placeholder: strings.rangePlaceholder,
      leading: Icons.date_range_outlined,
      isOpen: _isOpen,
      helperText: widget.helperText,
      errorText: widget.errorText,
    );
  }
}

@immutable
class _GPCalendarResult {
  const _GPCalendarResult(this.start, [this.end]);

  final DateTime start;
  final DateTime? end;
}

class _GPCalendar extends StatefulWidget {
  const _GPCalendar({required this.isRange, required this.today, required this.firstDate, required this.lastDate, this.initialStart, this.initialEnd});

  final bool isRange;
  final DateTime today;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? initialStart;
  final DateTime? initialEnd;

  @override
  State<_GPCalendar> createState() => _GPCalendarState();
}

class _GPCalendarState extends State<_GPCalendar> {
  late DateTime _visibleMonth = _month(widget.initialEnd ?? widget.initialStart ?? widget.lastDate);
  bool _showMonths = false;
  late DateTime? _start = widget.initialStart;
  late DateTime? _end = widget.initialEnd;

  DateTime get _firstMonth => _month(widget.firstDate);
  DateTime get _lastMonth => _month(widget.lastDate);

  bool _isPickable(DateTime day) => !day.isBefore(widget.firstDate) && !day.isAfter(widget.lastDate);

  bool get _canGoBack => _showMonths ? _visibleMonth.year > _firstMonth.year : _visibleMonth.isAfter(_firstMonth);
  bool get _canGoForward => _showMonths ? _visibleMonth.year < _lastMonth.year : _visibleMonth.isBefore(_lastMonth);

  void _step(int direction) => setState(() {
    final next = _showMonths ? DateTime(_visibleMonth.year + direction, _visibleMonth.month) : DateTime(_visibleMonth.year, _visibleMonth.month + direction);
    // A year step can land past either end; the month grid then shows the nearest month that exists.
    _visibleMonth = next.isAfter(_lastMonth)
        ? _lastMonth
        : next.isBefore(_firstMonth)
        ? _firstMonth
        : next;
  });

  void _pick(DateTime day) {
    if (!widget.isRange) {
      Navigator.of(context).pop(_GPCalendarResult(day));
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

  void _pickPreset(DateTime start, DateTime end) {
    final clampedStart = start.isBefore(widget.firstDate) ? widget.firstDate : start;
    final clampedEnd = end.isAfter(widget.lastDate) ? widget.lastDate : end;
    setState(() {
      _start = clampedStart;
      _end = clampedEnd;
      _visibleMonth = _month(clampedEnd);
      _showMonths = false;
    });
  }

  List<Widget> _presets(GPLocaleBaseWidgetsDatePicker strings) {
    final today = widget.today;
    if (!widget.isRange) {
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      return <Widget>[
        if (_isPickable(today)) GPChip(label: strings.today, selected: _start == today, onPressed: () => _pick(today)),
        if (_isPickable(yesterday)) GPChip(label: strings.yesterday, selected: _start == yesterday, onPressed: () => _pick(yesterday)),
      ];
    }

    final presets = <(String, DateTime, DateTime)>[
      (strings.last7Days, DateTime(today.year, today.month, today.day - 6), today),
      (strings.thisMonth, DateTime(today.year, today.month), today),
      (strings.lastMonth, DateTime(today.year, today.month - 1), DateTime(today.year, today.month, 0)),
    ];
    return <Widget>[
      for (final (String label, DateTime start, DateTime end) in presets) GPChip(label: label, selected: _start == start && _end == end, onPressed: () => _pickPreset(start, end)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final strings = l10n.widgets.datePicker;
    final spacing = context.spacing;
    final presets = _presets(strings);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: spacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (presets.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: spacing.sm),
              child: Wrap(spacing: spacing.sm, runSpacing: spacing.sm, children: presets),
            ),
          _GPCalendarHeader(
            label: _showMonths ? '${_visibleMonth.year}' : strings.monthYear(_visibleMonth.month, _visibleMonth.year),
            semanticLabel: _showMonths ? strings.backToDays(_visibleMonth.year) : strings.chooseMonth(_visibleMonth.month, _visibleMonth.year),
            isShowingMonths: _showMonths,
            onToggle: () => setState(() => _showMonths = !_showMonths),
            previousLabel: _showMonths ? strings.previousYear : strings.previousMonth,
            nextLabel: _showMonths ? strings.nextYear : strings.nextMonth,
            onPrevious: _canGoBack ? () => _step(-1) : null,
            onNext: _canGoForward ? () => _step(1) : null,
          ),
          if (_showMonths)
            _GPMonthGrid(
              year: _visibleMonth.year,
              selectedMonth: _visibleMonth.month,
              today: widget.today,
              firstMonth: _firstMonth,
              lastMonth: _lastMonth,
              strings: strings,
              onPick: (int month) => setState(() {
                _visibleMonth = DateTime(_visibleMonth.year, month);
                _showMonths = false;
              }),
            )
          else
            _GPDayGrid(
              month: _visibleMonth,
              today: widget.today,
              start: _start,
              end: widget.isRange ? _end : null,
              isPickable: _isPickable,
              labelOf: (DateTime day) => _fullDate(day, today: widget.today, l10n: l10n),
              weekdays: strings.weekdaysShort,
              onPick: _pick,
            ),
          if (widget.isRange) ...<Widget>[
            SizedBox(height: spacing.md),
            Text(
              _start != null && _end == null ? strings.rangeEndHint : strings.rangeStartHint,
              textAlign: TextAlign.center,
              style: context.text.bodySmall.copyWith(color: context.colors.onSurfaceVariant),
            ),
            SizedBox(height: spacing.sm),
            GPButton(
              label: strings.apply,
              expanded: true,
              onPressed: _start == null ? null : () => Navigator.of(context).pop(_GPCalendarResult(_start!, _end)),
            ),
          ],
        ],
      ),
    );
  }
}

class _GPCalendarHeader extends StatelessWidget {
  const _GPCalendarHeader({
    required this.label,
    required this.semanticLabel,
    required this.isShowingMonths,
    required this.onToggle,
    required this.previousLabel,
    required this.nextLabel,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final String semanticLabel;
  final bool isShowingMonths;
  final VoidCallback onToggle;
  final String previousLabel;
  final String nextLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: <Widget>[
        Semantics(
          button: true,
          label: semanticLabel,
          excludeSemantics: true,
          onTap: onToggle,
          child: InkWell(
            onTap: onToggle,
            borderRadius: context.radii.borderMd,
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
                child: Row(
                  children: <Widget>[
                    Text(
                      label,
                      style: context.text.titleMedium.copyWith(color: colors.onSurface, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: context.spacing.xs),
                    AnimatedRotation(
                      turns: isShowingMonths ? 0.5 : 0,
                      duration: GPDurationTokens.normal,
                      child: Icon(Icons.expand_more, size: 20, color: colors.onSurfaceVariant),
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

class _GPDayGrid extends StatelessWidget {
  const _GPDayGrid({
    required this.month,
    required this.today,
    required this.start,
    required this.end,
    required this.isPickable,
    required this.labelOf,
    required this.weekdays,
    required this.onPick,
  });

  final DateTime month;
  final DateTime today;
  final DateTime? start;
  final DateTime? end;
  final bool Function(DateTime day) isPickable;
  final String Function(DateTime day) labelOf;
  final List<String> weekdays;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    // Monday first: `weekday` runs 1 (Monday) to 7.
    final leading = DateTime(month.year, month.month).weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = <DateTime?>[for (var i = 0; i < leading; i++) null, for (var d = 1; d <= days; d++) DateTime(month.year, month.month, d)];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExcludeSemantics(
          child: Row(
            children: <Widget>[
              for (final name in weekdays)
                Expanded(
                  child: SizedBox(
                    height: 32,
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
            children: <Widget>[
              for (final day in cells.sublist(row, row + 7))
                Expanded(
                  child: day == null
                      ? const SizedBox(height: 44)
                      : _GPDayCell(day: day, today: today, start: start, end: end, isPickable: isPickable(day), label: labelOf(day), onPick: onPick),
                ),
            ],
          ),
      ],
    );
  }
}

class _GPDayCell extends StatelessWidget {
  const _GPDayCell({required this.day, required this.today, required this.start, required this.end, required this.isPickable, required this.label, required this.onPick});

  final DateTime day;
  final DateTime today;
  final DateTime? start;
  final DateTime? end;
  final bool isPickable;
  final String label;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isEndpoint = day == start || day == end;
    final hasSpan = start != null && end != null && start != end;
    final inSpan = hasSpan && day.isAfter(start!) && day.isBefore(end!);
    final isToday = day == today;

    // The band runs under the whole span and stops at the middle of each end's circle.
    final band = inSpan ? colors.accentContainer : null;
    final halfBand = hasSpan && isEndpoint
        ? LinearGradient(
            begin: day == start ? Alignment.centerLeft : Alignment.centerRight,
            end: day == start ? Alignment.centerRight : Alignment.centerLeft,
            colors: <Color>[Colors.transparent, Colors.transparent, colors.accentContainer, colors.accentContainer],
            stops: const <double>[0, 0.5, 0.5, 1],
          )
        : null;

    final Color foreground;
    if (!isPickable) {
      foreground = colors.onSurfaceVariant;
    } else if (isEndpoint) {
      foreground = colors.onPrimary;
    } else if (isToday) {
      foreground = colors.accentInk;
    } else if (inSpan) {
      foreground = colors.onAccentContainer;
    } else {
      foreground = colors.onSurface;
    }

    return Container(
      height: 44,
      decoration: BoxDecoration(color: band, gradient: halfBand),
      alignment: Alignment.center,
      child: Opacity(
        opacity: isPickable ? 1 : 0.45,
        child: Semantics(
          button: true,
          enabled: isPickable,
          selected: isEndpoint,
          label: label,
          excludeSemantics: true,
          onTap: isPickable ? () => onPick(day) : null,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: isPickable ? () => onPick(day) : null,
              customBorder: const CircleBorder(),
              child: Container(
                width: 40,
                height: 40,
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
                    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
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

class _GPMonthGrid extends StatelessWidget {
  const _GPMonthGrid({
    required this.year,
    required this.selectedMonth,
    required this.today,
    required this.firstMonth,
    required this.lastMonth,
    required this.strings,
    required this.onPick,
  });

  final int year;
  final int selectedMonth;
  final DateTime today;
  final DateTime firstMonth;
  final DateTime lastMonth;
  final GPLocaleBaseWidgetsDatePicker strings;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.sm),
      child: GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisExtent: 48, crossAxisSpacing: spacing.sm, mainAxisSpacing: spacing.sm),
        children: <Widget>[
          for (var month = 1; month <= 12; month++)
            Builder(
              builder: (BuildContext context) {
                final first = DateTime(year, month);
                final isPickable = !first.isBefore(firstMonth) && !first.isAfter(lastMonth);
                final isSelected = month == selectedMonth;
                final isCurrent = year == today.year && month == today.month;
                final foreground = !isPickable
                    ? colors.onSurfaceVariant
                    : isSelected
                    ? colors.onPrimary
                    : isCurrent
                    ? colors.accentInk
                    : colors.onSurface;

                return Opacity(
                  opacity: isPickable ? 1 : 0.45,
                  child: Semantics(
                    selected: isSelected,
                    child: Material(
                      color: isSelected && isPickable ? colors.primary : Colors.transparent,
                      shape: StadiumBorder(side: isCurrent && !isSelected && isPickable ? BorderSide(color: colors.accentInk, width: 1.5) : BorderSide.none),
                      child: InkWell(
                        onTap: isPickable ? () => onPick(month) : null,
                        customBorder: const StadiumBorder(),
                        child: Center(
                          child: Text(
                            strings.monthName(month),
                            style: context.text.bodyLarge.copyWith(color: foreground, fontWeight: isSelected || isCurrent ? FontWeight.w600 : null),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
