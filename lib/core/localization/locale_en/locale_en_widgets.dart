part of 'locale_en.dart';

final class GPLocaleEnWidgets implements GPLocaleBaseWidgets {
  const GPLocaleEnWidgets();

  @override
  GPLocaleBaseWidgetsDatePicker get datePicker => const GPLocaleEnWidgetsDatePicker();

  @override
  String get clearText => 'Clear text';

  @override
  String get dismiss => 'Close';

  @override
  String removeFilter(String label) => 'Remove filter $label';
}

final class GPLocaleEnWidgetsDatePicker implements GPLocaleBaseWidgetsDatePicker {
  const GPLocaleEnWidgetsDatePicker();

  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  @override
  String get title => 'Pick a date';

  @override
  String get rangeTitle => 'Pick a date range';

  @override
  String get rangePlaceholder => 'Pick a date range';

  @override
  String get apply => 'Apply';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get last7Days => 'Last 7 days';

  @override
  String get thisMonth => 'This month';

  @override
  String get lastMonth => 'Last month';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get previousYear => 'Previous year';

  @override
  String get nextYear => 'Next year';

  @override
  String get rangeStartHint => 'Tap a start day, then an end day';

  @override
  String get rangeEndHint => 'Pick an end day';

  @override
  List<String> get weekdaysShort => const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  String monthName(int month) => _months[month - 1];

  @override
  String monthYear({required int month, required int year}) => '${monthName(month)} $year';

  @override
  String chooseMonth({required int month, required int year}) => '${monthYear(month: month, year: year)}, choose another month';

  @override
  String backToDays(int year) => '$year, back to days';

  @override
  String range({required DateTime end, required DateTime start}) {
    if (start.year == end.year && start.month == end.month) return '${monthName(end.month)} ${start.day} – ${end.day}';
    return '${start.month}/${start.day} – ${end.month}/${end.day}';
  }
}
