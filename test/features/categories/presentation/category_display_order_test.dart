import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/categories/presentation/category_display_order.dart';

void main() {
  final at = DateTime.utc(2026, 10, 12);

  CategoryEntity seeded(String key) =>
      (CategoryEntity.create(id: key, nameKey: key, type: CategoryType.expense, isSystem: true, createdAt: at, updatedAt: at) as GPOk<CategoryEntity>).value;

  CategoryEntity mine(String name) => (CategoryEntity.create(id: name, name: name, type: CategoryType.expense, createdAt: at, updatedAt: at) as GPOk<CategoryEntity>).value;

  List<String> ids(List<CategoryEntity> categories) => [for (final category in categories) category.id];

  test('puts the seeds in seed order whatever order the repository returned them in, the catch-all last', () {
    final shuffled = [seeded('category.other_expense'), seeded('category.transport'), seeded('category.food')];

    expect(ids(inDisplayOrder(shuffled)), ['category.food', 'category.transport', 'category.other_expense']);
  });

  test("keeps the user's own after the seeds, in the order they came", () {
    final mixed = [mine('Trà sữa'), seeded('category.food'), mine('Cà phê')];

    expect(ids(inDisplayOrder(mixed)), ['category.food', 'Trà sữa', 'Cà phê']);
  });

  test('treats a seed this build does not know as one of the user’s own rather than dropping it', () {
    final newer = [seeded('category.pets'), seeded('category.food')];

    expect(ids(inDisplayOrder(newer)), ['category.food', 'category.pets']);
  });
}
