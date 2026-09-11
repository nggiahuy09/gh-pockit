part of 'locale_vi.dart';

final class GPLocaleViRoot implements GPLocaleBaseRoot {
  const GPLocaleViRoot();

  @override
  GPLocaleBaseRootBottomNav get bottomNav => const GPLocaleViRootBottomNav();

  @override
  String get appName => 'Pockit';

  @override
  String get backToHome => 'Về trang chủ';
}

final class GPLocaleViRootBottomNav implements GPLocaleBaseRootBottomNav {
  const GPLocaleViRootBottomNav();

  @override
  String get home => 'Trang chủ';

  @override
  String get accounts => 'Tài khoản';

  @override
  String get transactions => 'Giao dịch';

  @override
  String get budgets => 'Ngân sách';

  @override
  String get settings => 'Cài đặt';
}
