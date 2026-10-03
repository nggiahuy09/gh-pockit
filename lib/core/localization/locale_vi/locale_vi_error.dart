part of 'locale_vi.dart';

final class GPLocaleViError implements GPLocaleBaseError {
  const GPLocaleViError();

  @override
  String get network => 'Không có kết nối mạng.';

  @override
  String get timeout => 'Yêu cầu đã quá thời gian chờ.';

  @override
  String get authentication => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';

  @override
  String get authorization => 'Bạn không có quyền thực hiện thao tác này.';

  @override
  String get validationAccountNameEmpty => 'Tên tài khoản không được để trống.';

  @override
  String get validationAccountNameTooLong => 'Tên tài khoản quá dài.';

  @override
  String get validationAccountHasTransactions => 'Tài khoản đã có giao dịch nên không thể xóa. Hãy lưu trữ để ẩn tài khoản mà vẫn giữ lịch sử.';

  @override
  String get validationCategoryNameEmpty => 'Tên danh mục không được để trống.';

  @override
  String get validationCategoryNameTooLong => 'Tên danh mục quá dài.';

  @override
  String get validationTransactionAmountNotPositive => 'Số tiền phải lớn hơn 0.';

  @override
  String get validationTransactionDestinationMissing => 'Hãy chọn tài khoản nhận tiền.';

  @override
  String get validationTransactionDestinationSameAsSource => 'Không thể chuyển tiền vào chính tài khoản này.';

  @override
  String get validationTransactionNoteTooLong => 'Ghi chú quá dài.';

  @override
  String get validationTransactionCurrencyMismatch => 'Loại tiền của số tiền không khớp với tài khoản.';

  @override
  String get validationTransactionTransferCurrenciesDiffer => 'Hai tài khoản trong một lần chuyển phải dùng cùng loại tiền.';

  @override
  String get validationTransactionCategoryTypeMismatch => 'Khoản chi cần danh mục chi, khoản thu cần danh mục thu.';

  @override
  String get conflict => 'Mục này đã được thay đổi trên một thiết bị khác.';

  @override
  String get notFound => 'Mục này không còn tồn tại.';

  @override
  String get database => 'Không đọc được dữ liệu trên máy.';

  @override
  String get unknown => 'Đã có lỗi xảy ra.';

  @override
  String get routeNotFoundTitle => 'Không tìm thấy trang';

  @override
  String get routeNotFoundMessage => 'Liên kết này không dẫn tới đâu trong Pockit.';
}
