part of 'locale_vi.dart';

final class GPLocaleViTransactions implements GPLocaleBaseTransactions {
  const GPLocaleViTransactions();

  @override
  String get title => 'Giao dịch';

  @override
  String get typeExpense => 'Chi tiêu';

  @override
  String get typeIncome => 'Thu nhập';

  @override
  String get typeTransfer => 'Chuyển khoản';

  @override
  String get today => 'Hôm nay';

  @override
  String get yesterday => 'Hôm qua';

  @override
  String get add => 'Thêm giao dịch';

  @override
  String get addComingSoon => 'Màn thêm giao dịch đang được làm.';

  @override
  String get emptyTitle => 'Chưa có giao dịch nào';

  @override
  String get emptyMessage => 'Các khoản chi, thu và chuyển khoản của bạn sẽ hiện ở đây.';

  @override
  String get errorMessage => 'Danh sách sẽ tự hiện lại ở lần ghi dữ liệu tiếp theo.';

  @override
  String unreadable(int count) => '$count giao dịch không hiển thị được';

  @override
  String get loading => 'Đang tải giao dịch';

  @override
  String get loadingMore => 'Đang tải thêm';
}
