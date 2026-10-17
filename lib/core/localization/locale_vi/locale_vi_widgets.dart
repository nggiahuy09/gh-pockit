part of 'locale_vi.dart';

final class GPLocaleViWidgets implements GPLocaleBaseWidgets {
  const GPLocaleViWidgets();

  @override
  GPLocaleBaseWidgetsDatePicker get datePicker => const GPLocaleViWidgetsDatePicker();

  @override
  String get clearText => 'Xóa nội dung';

  @override
  String get dismiss => 'Đóng';

  @override
  String removeFilter(String label) => 'Bỏ lọc $label';
}

final class GPLocaleViWidgetsDatePicker implements GPLocaleBaseWidgetsDatePicker {
  const GPLocaleViWidgetsDatePicker();

  @override
  String get title => 'Chọn ngày';

  @override
  String get rangeTitle => 'Chọn khoảng ngày';

  @override
  String get rangePlaceholder => 'Chọn khoảng ngày';

  @override
  String get apply => 'Áp dụng';

  @override
  String get today => 'Hôm nay';

  @override
  String get yesterday => 'Hôm qua';

  @override
  String get last7Days => '7 ngày qua';

  @override
  String get thisMonth => 'Tháng này';

  @override
  String get lastMonth => 'Tháng trước';

  @override
  String get previousMonth => 'Tháng trước';

  @override
  String get nextMonth => 'Tháng sau';

  @override
  String get previousYear => 'Năm trước';

  @override
  String get nextYear => 'Năm sau';

  @override
  String get rangeStartHint => 'Chạm ngày bắt đầu, rồi ngày kết thúc';

  @override
  String get rangeEndHint => 'Chọn ngày kết thúc';

  @override
  List<String> get weekdaysShort => const <String>['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  String monthName(int month) => 'Tháng $month';

  @override
  String monthYear(int month, int year) => 'Tháng $month, $year';

  @override
  String chooseMonth(int month, int year) => 'Tháng $month năm $year, chọn tháng khác';

  @override
  String backToDays(int year) => 'Năm $year, quay lại lưới ngày';

  @override
  String range(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) return '${start.day} – ${end.day} tháng ${end.month}';
    return '${start.day}/${start.month} – ${end.day}/${end.month}';
  }
}
