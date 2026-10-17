part of 'locale_en.dart';

final class GPLocaleEnAccounts implements GPLocaleBaseAccounts {
  const GPLocaleEnAccounts();

  @override
  String get title => 'Accounts';

  @override
  String count(int count) => count == 1 ? '1 account' : '$count accounts';

  @override
  String get balanceColumn => 'Balance';

  @override
  String get loading => 'Loading accounts';

  @override
  String get errorMessage => 'The list comes back by itself the next time data is saved.';

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

  @override
  String get add => 'Add account';

  @override
  String get edit => 'Edit account';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldType => 'Type';

  @override
  String get fieldCurrency => 'Currency';

  @override
  String get currencyFixed => 'The currency cannot change once the account exists.';

  @override
  String get fieldInitialBalance => 'Opening balance';

  @override
  String get owed => 'I owe this amount (a card or a loan)';

  @override
  String get save => 'Save';
}
