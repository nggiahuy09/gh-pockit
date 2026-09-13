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
  String get validation => 'Vui lòng kiểm tra lại thông tin đã nhập.';

  @override
  String get conflict => 'Mục này đã được thay đổi trên một thiết bị khác.';

  @override
  String get database => 'Không đọc được dữ liệu trên máy.';

  @override
  String get unknown => 'Đã có lỗi xảy ra.';

  @override
  String get routeNotFoundTitle => 'Không tìm thấy trang';

  @override
  String get routeNotFoundMessage => 'Liên kết này không dẫn tới đâu trong Pockit.';
}
