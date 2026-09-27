part of 'locale_vi.dart';

final class GPLocaleViAccounts implements GPLocaleBaseAccounts {
  const GPLocaleViAccounts();

  @override
  String get title => 'Tài khoản';

  @override
  String get typeCash => 'Tiền mặt';

  @override
  String get typeBank => 'Ngân hàng';

  @override
  String get typeEWallet => 'Ví điện tử';

  @override
  String get typeCreditCard => 'Thẻ tín dụng';

  @override
  String get typeOther => 'Khác';

  @override
  String get emptyTitle => 'Chưa có tài khoản nào';

  @override
  String get emptyMessage => 'Tiền mặt, tài khoản ngân hàng, ví điện tử và thẻ của bạn sẽ hiện ở đây.';
}
