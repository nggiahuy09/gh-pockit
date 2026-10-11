import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/features/categories/data/seed/default_categories.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';

/// Exhaustive with no `default`, on purpose: a new [DefaultCategory] does not compile until both locales name it (ADR-0004).
extension DefaultCategoryName on DefaultCategory {
  String nameIn(GPLocaleBase l10n) {
    final categories = l10n.categories;

    return switch (this) {
      DefaultCategory.food => categories.food,
      DefaultCategory.transport => categories.transport,
      DefaultCategory.shopping => categories.shopping,
      DefaultCategory.bills => categories.bills,
      DefaultCategory.housing => categories.housing,
      DefaultCategory.health => categories.health,
      DefaultCategory.entertainment => categories.entertainment,
      DefaultCategory.education => categories.education,
      DefaultCategory.otherExpense => categories.otherExpense,
      DefaultCategory.salary => categories.salary,
      DefaultCategory.otherIncome => categories.otherIncome,
    };
  }
}

/// A typed [name] wins; otherwise [nameKey] is translated, or shown raw when this build does not know it (a newer build's seed).
/// Returns `''` only for an invalid row: a valid category always has one of the two.
String categoryDisplayName({required String? name, required String? nameKey, required GPLocaleBase l10n}) {
  if (name != null && name.isNotEmpty) return name;
  if (nameKey == null) return '';

  return DefaultCategory.fromNameKey(nameKey)?.nameIn(l10n) ?? nameKey;
}

extension CategoryEntityName on CategoryEntity {
  String displayNameIn(GPLocaleBase l10n) => categoryDisplayName(name: name, nameKey: nameKey, l10n: l10n);
}
