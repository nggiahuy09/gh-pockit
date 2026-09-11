part of 'locale_en.dart';

final class GPLocaleEnRoot implements GPLocaleBaseRoot {
  const GPLocaleEnRoot();

  @override
  GPLocaleBaseRootBottomNav get bottomNav => const GPLocaleEnRootBottomNav();

  @override
  String get appName => 'Pockit';

  @override
  String get backToHome => 'Back to home';
}

final class GPLocaleEnRootBottomNav implements GPLocaleBaseRootBottomNav {
  const GPLocaleEnRootBottomNav();

  @override
  String get home => 'Home';

  @override
  String get accounts => 'Accounts';

  @override
  String get transactions => 'Transactions';

  @override
  String get budgets => 'Budgets';

  @override
  String get settings => 'Settings';
}
