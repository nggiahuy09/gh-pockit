import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/categories/presentation/category_display_order.dart';

import '../../../helpers/results.dart';

final _at = DateTime.utc(2026, 10, 12);

CategoryEntity _seeded(String key) => okValue(CategoryEntity.create(type: CategoryType.expense, createdAt: _at, updatedAt: _at, id: key, nameKey: key, isSystem: true));

CategoryEntity _mine(String name) => okValue(CategoryEntity.create(type: CategoryType.expense, createdAt: _at, updatedAt: _at, id: name, name: name));

List<String> _ids(List<CategoryEntity> categories) => [for (final category in categories) category.id];

void main() {
  test('puts the seeds in seed order whatever order the repository returned them in, the catch-all last', () {
    final shuffled = [_seeded('category.other_expense'), _seeded('category.transport'), _seeded('category.food')];

    expect(_ids(inDisplayOrder(shuffled)), ['category.food', 'category.transport', 'category.other_expense']);
  });

  test("keeps the user's own after the seeds, in the order they came", () {
    final mixed = [_mine('Trà sữa'), _seeded('category.food'), _mine('Cà phê')];

    expect(_ids(inDisplayOrder(mixed)), ['category.food', 'Trà sữa', 'Cà phê']);
  });

  test('treats a seed this build does not know as one of the user’s own rather than dropping it', () {
    final newer = [_seeded('category.pets'), _seeded('category.food')];

    expect(_ids(inDisplayOrder(newer)), ['category.food', 'category.pets']);
  });
}
