import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/localization/locale_vi/locale_vi.dart';
import 'package:ghpockit/features/categories/data/seed/default_categories.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/categories/presentation/default_category_name.dart';

/// What makes storing `category.food` instead of "Ăn uống" actually work (W3 T5, ADR-0004).
void main() {
  const locales = <GPLocaleBase>[GPLocaleEn(), GPLocaleVi()];

  test('every seeded category has a name in every language we ship', () {
    // The completeness check ADR-0004 bought. The switch in `DefaultCategoryName` will not compile without a getter, and the getter will not compile until
    // both locales implement it — so this test is mostly here to state the invariant and to catch a getter that compiles while returning an empty string.
    for (final locale in locales) {
      for (final category in DefaultCategory.values) {
        expect(category.nameIn(locale), isNotEmpty, reason: '${category.nameKey} has no name in ${locale.locale.languageCode}');
      }
    }
  });

  test('no two categories share a name within a language', () {
    // Two categories reading the same in a picker is a usability bug that a translation pass introduces easily — "Other" for both the expense and the
    // income catch-all would be the obvious one.
    for (final locale in locales) {
      final names = DefaultCategory.values.map((c) => c.nameIn(locale)).toList();
      expect(names.toSet(), hasLength(names.length), reason: 'duplicate name in ${locale.locale.languageCode}');
    }
  });

  test('the two languages actually differ', () {
    // Guards against a copy-paste that leaves the Vietnamese file holding English strings — which compiles, passes every other test here, and ships.
    expect(DefaultCategory.food.nameIn(const GPLocaleEn()), 'Food & drink');
    expect(DefaultCategory.food.nameIn(const GPLocaleVi()), 'Ăn uống');
  });

  group('categoryDisplayName', () {
    test('resolves the key when the user has not renamed the category', () {
      expect(categoryDisplayName(name: null, nameKey: 'category.food', l10n: const GPLocaleVi()), 'Ăn uống');
      expect(categoryDisplayName(name: null, nameKey: 'category.food', l10n: const GPLocaleEn()), 'Food & drink');
    });

    test('lets the name the user typed win, in every language', () {
      // The other half of T5's rule. Translating somebody's own words would be absurd, so a non-null `name` short-circuits the lookup entirely.
      for (final locale in locales) {
        expect(categoryDisplayName(name: 'Cà phê sáng', nameKey: 'category.food', l10n: locale), 'Cà phê sáng');
      }
    });

    test('names a user-created category, which has no key at all', () {
      expect(categoryDisplayName(name: 'Cà phê', nameKey: null, l10n: const GPLocaleVi()), 'Cà phê');
    });

    test('falls back to the raw key for a category this build has never heard of', () {
      // Reachable without a bug: a row seeded by a newer build, opened after a downgrade. `category.pets` is honest and greppable; an empty row is neither.
      expect(categoryDisplayName(name: null, nameKey: 'category.pets', l10n: const GPLocaleEn()), 'category.pets');
    });

    test('treats an empty name as no name', () {
      // The table's CHECK accepts `name = ''` — it only asks that one of the two columns is non-null — so the display rule has to, rather than rendering a
      // blank line where a category should be.
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
      // The extension a screen actually calls. It exists so the rule lives in one function — and it is an extension rather than a getter on the entity
      // because resolving a key needs a locale, which `domain/` may not see.
      expect(entity(nameKey: 'category.food').displayNameIn(const GPLocaleVi()), 'Ăn uống');
      expect(entity(nameKey: 'category.food', name: 'Cà phê sáng').displayNameIn(const GPLocaleVi()), 'Cà phê sáng');
      expect(entity(name: 'Cà phê').displayNameIn(const GPLocaleEn()), 'Cà phê');
    });
  });
}
