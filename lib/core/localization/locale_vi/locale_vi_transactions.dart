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
  String get edit => 'Sửa giao dịch';

  @override
  String get emptyTitle => 'Chưa có giao dịch nào';

  @override
  String get emptyBody => 'Các khoản chi, thu và chuyển khoản của bạn sẽ hiện ở đây.';

  @override
  String get errorBody => 'Danh sách sẽ tự hiện lại ở lần ghi dữ liệu tiếp theo.';

  @override
  String get loading => 'Đang tải giao dịch';

  @override
  String get loadingMore => 'Đang tải thêm';

  @override
  String get fieldType => 'Loại';

  @override
  String get fieldAmount => 'Số tiền';

  @override
  String get fieldAccount => 'Tài khoản';

  @override
  String get fieldFromAccount => 'Từ tài khoản';

  @override
  String get fieldToAccount => 'Đến tài khoản';

  @override
  String get noDestinationMessage => 'Chuyển khoản cần một tài khoản khác cùng loại tiền.';

  @override
  String get fieldCategory => 'Danh mục';

  @override
  String get fieldDate => 'Ngày';

  @override
  String get fieldNote => 'Ghi chú';

  @override
  String get uncategorised => 'Chưa phân loại';

  @override
  String get save => 'Lưu';

  @override
  String get delete => 'Xóa';

  @override
  String get deleteConfirmTitle => 'Xóa giao dịch này?';

  @override
  String get deleted => 'Đã xóa giao dịch';

  @override
  String get undo => 'Hoàn tác';

  @override
  String get noAccountsTitle => 'Hãy thêm một tài khoản trước';

  @override
  String get noAccountsBody => 'Giao dịch cần một tài khoản để chi ra hoặc nhận vào.';

  @override
  String unreadable(int count) => '$count giao dịch không hiển thị được';
}
