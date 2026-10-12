import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/categories/domain/usecases/watch_categories_use_case.dart';

import '../../../../helpers/in_memory_repositories.dart';

void main() {
  late InMemoryRepositories repositories;

  setUp(() => repositories = InMemoryRepositories());
  tearDown(() => repositories.close());

  test('passes the type filter through, and watches both kinds without one', () async {
    await repositories.categories.createCategory(name: 'Cà phê', type: CategoryType.expense);
    await repositories.categories.createCategory(name: 'Thưởng', type: CategoryType.income);
    final watch = WatchCategoriesUseCase(categoryRepository: repositories.categories);

    expect((await watch().first).map((CategoryEntity c) => c.name), <String>['Cà phê', 'Thưởng']);
    expect((await watch(type: CategoryType.income).first).map((CategoryEntity c) => c.name), <String>['Thưởng']);
  });

  test('is the repository stream, so a later write reaches it', () async {
    final watch = WatchCategoriesUseCase(categoryRepository: repositories.categories);
    final emissions = watch().map((List<CategoryEntity> list) => list.length).take(2).toList();

    await pumpEventQueue();
    expect(await repositories.categories.createCategory(name: 'Trà', type: CategoryType.expense), isA<GPOk<CategoryEntity>>());

    expect(await emissions, <int>[0, 1]);
  });
}
