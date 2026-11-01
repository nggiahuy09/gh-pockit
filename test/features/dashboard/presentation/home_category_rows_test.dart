import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/dashboard/presentation/home_category_rows.dart';
import 'package:ghpockit/features/transactions/domain/entities/category_spending.dart';

import '../../../helpers/results.dart';

CategorySpending _spent(String? id, int minorUnits) => CategorySpending(category: id == null ? null : _category(id), amount: Money(minorUnits, 'VND'));

CategoryEntity _category(String id) => okValue(CategoryEntity.create(type: CategoryType.expense, createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026), id: id, name: id));

/// The canvas's numbers: October 2026, 6.214.000 ₫ spent.
final List<CategorySpending> _october = [
  _spent('food', 2140000),
  _spent('bills', 1486000),
  _spent('transport', 962000),
  _spent('shopping', 890000),
  _spent('fun', 420000),
  _spent(null, 316000),
];

void main() {
  test('lists the three largest, then "Uncategorised", and sums the rest into one line', () {
    final rows = HomeCategoryRows.of(_october);

    expect(rows.rows.map((row) => row.category?.id), ['food', 'bills', 'transport', null]);
    expect(rows.restCount, 2);
    expect(rows.rest, Money(1310000, 'VND'));
  });

  test('the rows and the rest line add up to the whole month', () {
    final rows = HomeCategoryRows.of(_october);

    final listed = rows.rows.map((row) => row.amount).reduce((a, b) => a + b);
    expect((listed + rows.rest!).minorUnits, 6214000);
    expect(rows.totalMinor, 6214000);
  });

  test('"Uncategorised" stays last even when it is the largest, and the bar scale counts it', () {
    final rows = HomeCategoryRows.of([_spent(null, 500000), _spent('food', 100000)]);

    expect(rows.rows.map((row) => row.category?.id), ['food', null]);
    expect(rows.barOf(Money(500000, 'VND')), 1.0);
    expect(rows.barOf(Money(100000, 'VND')), 0.2);
  });

  test('shares are of the month, rounded half up', () {
    final rows = HomeCategoryRows.of(_october);

    expect(rows.percentOf(Money(2140000, 'VND')), 34);
    expect(rows.percentOf(Money(316000, 'VND')), 5);
    expect(HomeCategoryRows.of([_spent('a', 1), _spent('b', 1)]).percentOf(Money(1, 'VND')), 50);
    expect(HomeCategoryRows.of([_spent('a', 1), _spent('b', 199)]).percentOf(Money(1, 'VND')), 1, reason: '0.5% rounds up');
  });

  test('no rest line when every category fits, and nothing at all for an empty month', () {
    expect(HomeCategoryRows.of([_spent('food', 45000)]).rest, isNull);
    expect(HomeCategoryRows.of(const []).isEmpty, isTrue);
  });
}
