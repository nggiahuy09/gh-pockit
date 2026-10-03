/// Which way the money moves — blueprint §17: out of an account, into one, or from one account to another.
///
/// **The type is the sign.** `amount_minor` is a positive magnitude and this is what gives it a direction (ADR-0009): an expense subtracts from its account,
/// an income adds to it, and a transfer does both at once, to two different accounts. That last case is why there is no signed amount to fall back on — a
/// single transfer row has no sign that is right for both of its sides.
///
/// **It also decides which optional reference a transaction may carry.** A transfer has a destination account and no category — it moves money between two
/// accounts the user owns, so it is spending in no category at all, which is why `CategoryType` has no transfer value. An expense or an income has no
/// destination and may have a category. `TransactionEntity.create` normalises to that shape, and the table's CHECKs refuse anything else at W4 T3.
///
/// [storageValue] is explicit and never derived from [name] — see `AccountType` for the argument against drift's `textEnum`. `'transfer'` is load bearing
/// twice over: the table's CHECK names it as a literal, so renaming it is a table rebuild on top of the data migration any storage rename already is.
enum TransactionType {
  expense('expense'),
  income('income'),
  transfer('transfer');

  const TransactionType(this.storageValue);

  /// The exact string in the `transactions.type` column.
  final String storageValue;

  /// The inverse of [storageValue], or null when [value] is not one of ours — a corrupt row or one written by a newer build, which the mapper reports as an
  /// unreadable row (ADR-0011) rather than a value to guess at.
  static TransactionType? fromStorage(String value) {
    for (final type in values) {
      if (type.storageValue == value) return type;
    }

    return null;
  }
}
