part of 'locale_base.dart';

/// Accounts tab. Grows with the account form at W6.
abstract class GPLocaleBaseAccounts {
  const GPLocaleBaseAccounts();

  String get title;

  /// One getter per `AccountType`, read through the exhaustive switch in `features/accounts/presentation/account_type_label.dart` — so a sixth type does
  /// not compile until both languages name it (ADR-0004). Never the stored value: `e_wallet` is what SQLite reads, "E-wallet" is what a person reads.
  String get typeCash;
  String get typeBank;
  String get typeEWallet;
  String get typeCreditCard;
  String get typeOther;

  String get emptyTitle;

  /// Describes what the list is for rather than inviting an action: there is no way to add an account until the form of W6, and a sentence that says
  /// "tap to add" over a screen with nothing to tap is worse than no sentence.
  String get emptyMessage;
}
