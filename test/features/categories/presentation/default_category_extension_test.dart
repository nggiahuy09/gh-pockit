import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/localization/locale_vi/locale_vi.dart';
import 'package:ghpockit/features/categories/data/seed/default_categories.dart';
import 'package:ghpockit/features/categories/presentation/default_category_extension.dart';

const _locales = <GPLocaleBase>[GPLocaleEn(), GPLocaleVi()];

void main() {
  test('every seeded category has a title in every language we ship', () {
    // The compiler already demands every case in both locales; this catches a getter that returns ''.
    for (final locale in _locales) {
      for (final category in DefaultCategory.values) {
        expect(category.getTitle(locale), isNotEmpty, reason: '${category.nameKey} has no title in ${locale.locale.languageCode}');
      }
    }
  });

  test('no two categories share a title within a language', () {
    for (final locale in _locales) {
      final titles = DefaultCategory.values.map((category) => category.getTitle(locale)).toList();
      expect(titles.toSet(), hasLength(titles.length), reason: 'duplicate title in ${locale.locale.languageCode}');
    }
  });

  test('the two languages actually differ', () {
    expect(DefaultCategory.food.getTitle(const GPLocaleEn()), 'Food & drink');
    expect(DefaultCategory.food.getTitle(const GPLocaleVi()), 'Ăn uống');
  });
}
