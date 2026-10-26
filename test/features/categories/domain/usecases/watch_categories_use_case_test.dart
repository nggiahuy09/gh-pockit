import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/domain/use_case.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/categories/domain/usecases/watch_categories_use_case.dart';

import '../../../../helpers/in_memory_repositories.dart';
import '../../../../helpers/results.dart';

void main() {
  late InMemoryRepositories repositories;

  setUp(() => repositories = InMemoryRepositories());
  tearDown(() => repositories.close());

  test('watches both kinds, in the repository order', () async {
    await repositories.categories.createCategory(type: CategoryType.expense, name: 'Cà phê');
    await repositories.categories.createCategory(type: CategoryType.income, name: 'Thưởng');

    final categories = await WatchCategoriesUseCase(repositories.categories).execute(const GPNoInput()).first;

    expect(categories.map((category) => category.name), ['Cà phê', 'Thưởng']);
  });

  test('is the repository stream, so a later write reaches it', () async {
    final emissions = WatchCategoriesUseCase(repositories.categories).execute(const GPNoInput()).map((categories) => categories.length).take(2).toList();

    await pumpEventQueue();
    okValue(await repositories.categories.createCategory(type: CategoryType.expense, name: 'Trà'));

    expect(await emissions, [0, 1]);
  });
}
