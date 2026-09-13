part of 'locale_base.dart';

/// Strings that belong to no single feature: the app name and the shell chrome around every tab.
abstract class GPLocaleBaseRoot {
  const GPLocaleBaseRoot();

  GPLocaleBaseRootBottomNav get bottomNav;

  String get appName;
  String get backToHome;
}

abstract class GPLocaleBaseRootBottomNav {
  const GPLocaleBaseRootBottomNav();

  String get home;
  String get accounts;
  String get transactions;
  String get budgets;
  String get settings;
}
