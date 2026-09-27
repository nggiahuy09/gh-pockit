part of 'locale_en.dart';

final class GPLocaleEnAccounts implements GPLocaleBaseAccounts {
  const GPLocaleEnAccounts();

  @override
  String get title => 'Accounts';

  @override
  String get typeCash => 'Cash';

  @override
  String get typeBank => 'Bank';

  @override
  String get typeEWallet => 'E-wallet';

  @override
  String get typeCreditCard => 'Credit card';

  @override
  String get typeOther => 'Other';

  @override
  String get emptyTitle => 'No accounts yet';

  @override
  String get emptyMessage => 'Your cash, bank accounts, e-wallets and cards will show up here.';
}
