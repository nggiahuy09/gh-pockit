/// No `transfer`: a transfer row has no category.
enum CategoryType {
  expense('expense'),
  income('income');

  const CategoryType(this.storageValue);

  /// Written out, never derived from `name`: renaming a value must not orphan stored rows.
  final String storageValue;

  static CategoryType? fromStorage(String value) => values.where((type) => type.storageValue == value).firstOrNull;
}
