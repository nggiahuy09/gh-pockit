enum AccountType {
  cash('cash'),
  bank('bank'),
  eWallet('e_wallet'),
  creditCard('credit_card'),
  other('other');

  const AccountType(this.storageValue);

  /// The `accounts.type` value. Written out, never derived from [name]: renaming a constant must not orphan stored rows.
  final String storageValue;

  /// Null for a value no type stores. Never falls back to [other]: the next edit would overwrite the stored value.
  static AccountType? fromStorage(String value) {
    for (final type in values) {
      if (type.storageValue == value) return type;
    }

    return null;
  }
}
