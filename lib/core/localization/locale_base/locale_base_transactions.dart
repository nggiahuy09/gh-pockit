part of 'locale_base.dart';

abstract class GPLocaleBaseTransactions {
  const GPLocaleBaseTransactions();

  String get title;
  String get typeExpense;
  String get typeIncome;
  String get typeTransfer;
  String get today;
  String get yesterday;
  String get add;
  String get addComingSoon;
  String get emptyTitle;
  String get emptyMessage;
  String get errorMessage;
  String unreadable(int count);
  String get loading;
  String get loadingMore;
}
