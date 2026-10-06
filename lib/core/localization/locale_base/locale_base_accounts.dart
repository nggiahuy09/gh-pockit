part of 'locale_base.dart';

abstract class GPLocaleBaseAccounts {
  const GPLocaleBaseAccounts();

  String get title;

  /// One per `AccountType`, mapped by the exhaustive switch in `account_type_label.dart`.
  String get typeCash;
  String get typeBank;
  String get typeEWallet;
  String get typeCreditCard;
  String get typeOther;

  String get emptyTitle;

  /// No "tap to add" until the account form exists (W6): there is nothing to tap yet.
  String get emptyMessage;
}
