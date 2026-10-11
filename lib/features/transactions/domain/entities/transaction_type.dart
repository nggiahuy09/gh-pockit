/// The sign of a transaction: amounts are always positive and the type gives the direction (ADR-0009).
enum TransactionType {
  expense('expense'),
  income('income'),
  transfer('transfer');

  const TransactionType(this.storageValue);

  /// The `transactions.type` value; never derive it from [name]. Renaming one is a data migration, and `'transfer'` is a literal in the table's CHECKs.
  final String storageValue;

  static TransactionType? fromStorage(String value) {
    for (final type in values) {
      if (type.storageValue == value) return type;
    }

    return null;
  }
}
