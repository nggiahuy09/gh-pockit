/// What kind of account this is — blueprint §Accounts: cash, bank, e-wallet, credit card, other.
///
/// It is presentation-only today: nothing in the domain branches on it, and the balance of a credit card is computed exactly like the balance of a wallet.
/// It still exists as a closed set rather than a free-text label because W6's account picker groups by it, and because a typo in a string column is a row
/// that silently belongs to no group.
///
/// **Every value carries an explicit [storageValue], and that is the point of this enum.** `accounts_table.dart` stores the type as plain `TEXT` and
/// deliberately refuses drift's `textEnum<AccountType>()`, which persists the Dart constant's *name*: under `textEnum`, renaming `eWallet` to `ewallet` is a
/// silent data migration — the code compiles, every existing row stops matching, and nothing fails until a user notices their accounts lost their type.
/// Writing the stored vocabulary out by hand makes the persisted alphabet a thing a reviewer sees in the diff, and makes a rename a two-line change with the
/// data part visible.
///
/// Snake case for the stored values, not camel case: these strings end up in a Postgres column at W10 and in JSON on the wire, and both are snake-case
/// conventions. The Dart names stay camel case because Dart is.
enum AccountType {
  cash('cash'),
  bank('bank'),
  eWallet('e_wallet'),
  creditCard('credit_card'),

  /// The deliberate escape hatch. A closed set with no "other" pushes people to file a brokerage account under `bank`, which is worse data than an honest
  /// "not one of the above".
  other('other');

  const AccountType(this.storageValue);

  /// The exact string in the `accounts.type` column. Never derived from [name] — see the class doc.
  final String storageValue;

  /// The inverse of [storageValue], or null when [value] is not one of ours.
  ///
  /// Nullable rather than throwing or falling back to [other], because the caller is `AccountMapper` at T6 and it is the layer that gets to decide: an
  /// unknown type in a local row means the row is corrupt or was written by a newer build, and that is a `GPDatabaseFailure`, not an account that quietly
  /// becomes "Other". Falling back here would hide it and then write the fallback back on the next edit, destroying the original value.
  static AccountType? fromStorage(String value) {
    for (final type in values) {
      if (type.storageValue == value) return type;
    }

    return null;
  }
}
