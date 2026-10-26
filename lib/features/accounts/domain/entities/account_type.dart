enum AccountType {
  cash('cash'),
  bank('bank'),
  eWallet('e_wallet'),
  creditCard('credit_card'),
  other('other');

  const AccountType(this.storageValue);

  /// Written out, never derived from `name`: renaming a value must not orphan stored rows.
  final String storageValue;

  /// Null rather than [other]: the next edit would overwrite the stored value.
  static AccountType? fromStorage(String value) => values.where((type) => type.storageValue == value).firstOrNull;
}
