import '../../../core/localization/locale_base/locale_base.dart';
import '../data/seed/default_categories.dart';

/// No wildcard: a new [DefaultCategory] does not compile until both locales name it (ADR-0004).
extension DefaultCategoryExtension on DefaultCategory {
  String getTitle(GPLocaleBase locale) {
    final categoriesLocale = locale.categories;
    return switch (this) {
      DefaultCategory.food => categoriesLocale.food,
      DefaultCategory.transport => categoriesLocale.transport,
      DefaultCategory.shopping => categoriesLocale.shopping,
      DefaultCategory.bills => categoriesLocale.bills,
      DefaultCategory.housing => categoriesLocale.housing,
      DefaultCategory.health => categoriesLocale.health,
      DefaultCategory.entertainment => categoriesLocale.entertainment,
      DefaultCategory.education => categoriesLocale.education,
      DefaultCategory.otherExpense => categoriesLocale.otherExpense,
      DefaultCategory.salary => categoriesLocale.salary,
      DefaultCategory.otherIncome => categoriesLocale.otherIncome,
    };
  }
}
