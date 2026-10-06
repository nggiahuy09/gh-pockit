import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';

void main() {
  test('stores the strings the schema and the wire expect', () {
    expect(CategoryType.expense.storageValue, 'expense');
    expect(CategoryType.income.storageValue, 'income');
  });

  test('round-trips every value through storage', () {
    for (final type in CategoryType.values) {
      expect(CategoryType.fromStorage(type.storageValue), type);
    }
  });

  test('returns null for a value it does not know', () {
    expect(CategoryType.fromStorage('transfer'), isNull);
    expect(CategoryType.fromStorage('Expense'), isNull);
    expect(CategoryType.fromStorage(''), isNull);
  });

  test('has no transfer value, on purpose', () {
    // A transfer has no category (`category_id` is null); a third value here is how one ends up counted as both income and expense.
    expect(CategoryType.values.map((t) => t.name), ['expense', 'income']);
  });
}
