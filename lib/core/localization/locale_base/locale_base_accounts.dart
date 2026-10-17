part of 'locale_base.dart';

abstract class GPLocaleBaseAccounts {
  const GPLocaleBaseAccounts();

  String get title;

  /// The list's heading on the Accounts tab: "5 accounts".
  String count(int count);

  /// Above the balance column.
  String get balanceColumn;
  String get loading;

  /// Under a read failure: the list comes back by itself with the next write.
  String get errorMessage;

  /// One per `AccountType`, mapped by the exhaustive switch in `account_type_label.dart`.
  String get typeCash;
  String get typeBank;
  String get typeEWallet;
  String get typeCreditCard;
  String get typeOther;

  String get emptyTitle;
  String get emptyMessage;

  String get add;
  String get edit;
  String get fieldName;
  String get fieldType;
  String get fieldCurrency;

  /// Shown under the currency on edit: it is fixed at creation (ADR-0010).
  String get currencyFixed;

  String get fieldInitialBalance;

  /// The switch that makes the opening balance negative.
  String get owed;

  String get save;
}
