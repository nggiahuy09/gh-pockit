import 'package:ghpockit/features/categories/domain/entities/category_type.dart';

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

extension TransactionTypeCategory on TransactionType {
  /// The kind of category this type is filed under (ADR-0010 rule 3). Null for a transfer, which has no category.
  CategoryType? get categoryType => switch (this) {
    TransactionType.expense => CategoryType.expense,
    TransactionType.income => CategoryType.income,
    TransactionType.transfer => null,
  };
}
