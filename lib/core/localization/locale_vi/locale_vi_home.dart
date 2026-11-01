part of 'locale_vi.dart';

final class GPLocaleViHome implements GPLocaleBaseHome {
  const GPLocaleViHome();

  @override
  String get title => 'Trang chủ';

  @override
  String get seeAllAccounts => 'Xem tất cả';

  @override
  String get netThisMonth => 'Thu − chi tháng này';

  @override
  String get loadingMonth => 'Đang tải tổng thu chi tháng';

  @override
  String get spendingByCategory => 'Chi theo danh mục';

  @override
  String get loadingSpending => 'Đang tải chi tiêu theo danh mục';

  @override
  String get noSpendingTitle => 'Chưa có khoản chi nào tháng này';

  @override
  String get noSpendingBody => 'Mỗi khoản chi sẽ được cộng vào danh mục của nó ở đây.';

  @override
  String get sectionErrorBody => 'Phần này sẽ tự hiện lại ở lần ghi dữ liệu tiếp theo.';

  @override
  String otherCategories(int count) => '$count danh mục khác';

  @override
  String categoryShare({required String amount, required String name, required int percent}) => '$name, $amount, $percent% chi tiêu tháng';
}
