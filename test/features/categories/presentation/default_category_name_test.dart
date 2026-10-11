import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/localization/locale_vi/locale_vi.dart';
import 'package:ghpockit/features/categories/data/seed/default_categories.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/categories/presentation/default_category_name.dart';

void main() {
  const locales = <GPLocaleBase>[GPLocaleEn(), GPLocaleVi()];

  test('every seeded category has a name in every language we ship', () {
    // The compiler already demands every case in both locales; what this catches is a getter that returns ''.
    for (final locale in locales) {
      for (final category in DefaultCategory.values) {
        expect(category.nameIn(locale), isNotEmpty, reason: '${category.nameKey} has no name in ${locale.locale.languageCode}');
      }
    }
  });

  test('no two categories share a name within a language', () {
    for (final locale in locales) {
      final names = DefaultCategory.values.map((c) => c.nameIn(locale)).toList();
      expect(names.toSet(), hasLength(names.length), reason: 'duplicate name in ${locale.locale.languageCode}');
    }
  });

  test('the two languages actually differ', () {
    expect(DefaultCategory.food.nameIn(const GPLocaleEn()), 'Food & drink');
    expect(DefaultCategory.food.nameIn(const GPLocaleVi()), 'Ăn uống');
  });

  group('categoryDisplayName', () {
    test('resolves the key when the user has not renamed the category', () {
      expect(categoryDisplayName(name: null, nameKey: 'category.food', l10n: const GPLocaleVi()), 'Ăn uống');
      expect(categoryDisplayName(name: null, nameKey: 'category.food', l10n: const GPLocaleEn()), 'Food & drink');
    });

    test('lets the name the user typed win, in every language', () {
      for (final locale in locales) {
        expect(categoryDisplayName(name: 'Cà phê sáng', nameKey: 'category.food', l10n: locale), 'Cà phê sáng');
      }
    });

    test('names a user-created category, which has no key at all', () {
      expect(categoryDisplayName(name: 'Cà phê', nameKey: null, l10n: const GPLocaleVi()), 'Cà phê');
    });

    test('falls back to the raw key for a category this build has never heard of', () {
      expect(categoryDisplayName(name: null, nameKey: 'category.pets', l10n: const GPLocaleEn()), 'category.pets');
    });

    test('treats an empty name as no name', () {
      // The table's CHECK only asks for one non-null name column, so `name = ''` can reach this.
      expect(categoryDisplayName(name: '', nameKey: 'category.food', l10n: const GPLocaleEn()), 'Food & drink');
    });
  });

  group('displayNameIn', () {
    CategoryEntity entity({String? nameKey, String? name}) =>
        (CategoryEntity.create(
                  id: 'c1',
                  nameKey: nameKey,
                  name: name,
                  type: CategoryType.expense,
                  createdAt: DateTime.utc(2026, 9, 22),
                  updatedAt: DateTime.utc(2026, 9, 22),
                )
                as GPOk<CategoryEntity>)
            .value;

    test('reads an entity the same way the raw columns read', () {
      expect(entity(nameKey: 'category.food').displayNameIn(const GPLocaleVi()), 'Ăn uống');
      expect(entity(nameKey: 'category.food', name: 'Cà phê sáng').displayNameIn(const GPLocaleVi()), 'Cà phê sáng');
      expect(entity(name: 'Cà phê').displayNameIn(const GPLocaleEn()), 'Cà phê');
    });
  });
}
