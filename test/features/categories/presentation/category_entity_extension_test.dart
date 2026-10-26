import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/localization/locale_vi/locale_vi.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/categories/presentation/category_entity_extension.dart';

import '../../../helpers/results.dart';

const _locales = <GPLocaleBase>[GPLocaleEn(), GPLocaleVi()];

CategoryEntity _entity({String? name, String? nameKey}) => okValue(
  CategoryEntity.create(type: CategoryType.expense, createdAt: DateTime.utc(2026, 9, 22), updatedAt: DateTime.utc(2026, 9, 22), id: 'c1', name: name, nameKey: nameKey),
);

void main() {
  test('resolves the key when the user has not renamed the category', () {
    expect(_entity(nameKey: 'category.food').getTitle(const GPLocaleVi()), 'Ăn uống');
    expect(_entity(nameKey: 'category.food').getTitle(const GPLocaleEn()), 'Food & drink');
  });

  test('lets the name the user typed win, in every language', () {
    for (final locale in _locales) {
      expect(_entity(name: 'Cà phê sáng', nameKey: 'category.food').getTitle(locale), 'Cà phê sáng');
    }
  });

  test('names a user-created category, which has no key at all', () {
    expect(_entity(name: 'Cà phê').getTitle(const GPLocaleVi()), 'Cà phê');
  });

  test('falls back to the raw key for a category this build has never heard of', () {
    expect(_entity(nameKey: 'category.pets').getTitle(const GPLocaleEn()), 'category.pets');
  });

  test('treats a blank name as no name', () {
    expect(_entity(name: '  ', nameKey: 'category.food').getTitle(const GPLocaleEn()), 'Food & drink');
  });
}
