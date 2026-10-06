/// No `transfer`, on purpose: a transfer row has no category.
enum CategoryType {
  expense('expense'),
  income('income');

  const CategoryType(this.storageValue);

  /// What `categories.type` stores. Spelled out rather than taken from `name`, so renaming a value cannot orphan stored rows.
  final String storageValue;

  /// Null for a value this build does not know: a newer build's row, or a corrupt one.
  static CategoryType? fromStorage(String value) {
    for (final type in values) {
      if (type.storageValue == value) return type;
    }

    return null;
  }
}
