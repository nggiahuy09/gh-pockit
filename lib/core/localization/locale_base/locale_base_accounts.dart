part of 'locale_base.dart';

abstract class GPLocaleBaseAccounts {
  const GPLocaleBaseAccounts();

  String get title;

  String get balanceColumn;

  String get loading;

  String get errorBody;

  String get typeCash;

  String get typeBank;

  String get typeEWallet;

  String get typeCreditCard;

  String get typeOther;

  String get emptyTitle;

  String get emptyBody;

  String get add;

  String get edit;

  String get fieldName;

  String get fieldType;

  String get fieldCurrency;

  String get currencyFixed;

  String get fieldInitialBalance;

  String get owed;

  String get save;

  String count(int count);
}
