import '../../../categories/domain/entities/category_type.dart';

/// Amounts are always positive; the type gives the direction (ADR-0009).
enum TransactionType {
  expense('expense'),
  income('income'),
  transfer('transfer');

  const TransactionType(this.storageValue);

  /// Never derived from `name`: renaming one is a data migration, and `'transfer'` is a literal in the table's CHECKs.
  final String storageValue;

  static TransactionType? fromStorage(String value) => values.where((type) => type.storageValue == value).firstOrNull;

  bool get isTransfer => this == TransactionType.transfer;

  /// The kind of category this type is filed under (ADR-0010 rule 3).
  CategoryType? get categoryType => switch (this) {
    TransactionType.expense => CategoryType.expense,
    TransactionType.income => CategoryType.income,
    TransactionType.transfer => null,
  };
}
