part of 'locale_base.dart';

/// Strings owned by the shared widgets in `core/widgets/`, not by any feature.
abstract class GPLocaleBaseWidgets {
  const GPLocaleBaseWidgets();

  GPLocaleBaseWidgetsDatePicker get datePicker;

  /// The text field's clear button.
  String get clearText;

  /// The scrim behind a sheet, read out as a button.
  String get dismiss;

  /// The remove button on a filter chip.
  String removeFilter(String label);
}

abstract class GPLocaleBaseWidgetsDatePicker {
  const GPLocaleBaseWidgetsDatePicker();

  String get title;
  String get rangeTitle;
  String get rangePlaceholder;
  String get apply;
  String get today;
  String get yesterday;
  String get last7Days;
  String get thisMonth;
  String get lastMonth;
  String get previousMonth;
  String get nextMonth;
  String get previousYear;
  String get nextYear;
  String get rangeStartHint;
  String get rangeEndHint;

  /// Monday first, seven entries.
  List<String> get weekdaysShort;

  /// [month] is 1–12.
  String monthName(int month);
  String monthYear(int month, int year);

  /// The month button's label for a screen reader, in the day grid and in the month grid.
  String chooseMonth(int month, int year);
  String backToDays(int year);

  /// Both ends are local dates; the start's year is left out, as the field only ever shows recent ranges.
  String range(DateTime start, DateTime end);
}
