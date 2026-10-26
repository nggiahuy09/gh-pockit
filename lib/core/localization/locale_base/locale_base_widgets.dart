part of 'locale_base.dart';

abstract class GPLocaleBaseWidgets {
  const GPLocaleBaseWidgets();

  GPLocaleBaseWidgetsDatePicker get datePicker;

  String get clearText;

  String get dismiss;

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
  String monthYear({required int month, required int year});

  String chooseMonth({required int month, required int year});
  String backToDays(int year);

  /// Both ends are local dates; the start's year is left out, as the field only ever shows recent ranges.
  String range({required DateTime end, required DateTime start});
}
