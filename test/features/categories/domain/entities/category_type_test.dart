import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';

/// `CategoryType` (pulled forward from W3 T6 into T5, because the seeder has to name a type).
void main() {
  test('stores the strings the schema and the wire expect', () {
    // Snake case, written out rather than derived from `name` — the argument against drift's `textEnum` is in `AccountType`'s doc, and these strings end up
    // in a Postgres column at W10.
    expect(CategoryType.expense.storageValue, 'expense');
    expect(CategoryType.income.storageValue, 'income');
  });

  test('round-trips every value through storage', () {
    for (final type in CategoryType.values) {
      expect(CategoryType.fromStorage(type.storageValue), type);
    }
  });

  test('returns null for a value it does not know', () {
    // A corrupt row or one from a newer build. Null lets the mapper raise a `GPDatabaseFailure` at T6 instead of the enum guessing — a fallback here would
    // hide the bad value and then write the guess back on the next edit.
    expect(CategoryType.fromStorage('transfer'), isNull);
    expect(CategoryType.fromStorage('Expense'), isNull);
    expect(CategoryType.fromStorage(''), isNull);
  });

  test('has no transfer value, on purpose', () {
    // A transfer belongs to no spending category: `TransactionType` carries it at W4 and the row simply has no `category_id`. A third value here is how a
    // transfer ends up counted as both income and expense.
    expect(CategoryType.values.map((t) => t.name), ['expense', 'income']);
  });
}
