import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/features/categories/data/seed/default_categories.dart';

/// Turns a seeded category's key into text in the active language.
///
/// **This switch is the mechanism ADR-0004 is about.** It is exhaustive with no `default` branch, so adding a value to [DefaultCategory] stops the app
/// compiling until a string exists here — and the getter it needs does not exist until both `GPLocaleEn` and `GPLocaleVi` implement it. A default category
/// with no Vietnamese name is therefore not a thing that can ship; with ARB files it would have been a runtime fallback nobody noticed.
///
/// **In presentation, not in `core/` and not in `domain/`.** `core/localization/` holds the strings and no feature's rules (§3), the domain carries no
/// message at all, and this — a key becoming text — is the mapping presentation is for. It is the same shape as the `Failure` → `l10n.error.*` mapping.
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

/// What to show for a category row, given the two name columns and the active language.
///
/// The rule T5 exists to establish: **a name the user typed always wins.** [name] is null on a seeded category nobody has touched, and then the key is
/// resolved; it is non-null on a category the user created or renamed, and then no lookup happens at all — translating somebody's own words would be absurd.
///
/// The last fallback is the raw [nameKey]. It is reachable without a bug: a category seeded by a newer build carries a key this version has never heard of,
/// and printing `category.pets` is honest, greppable, and better than an empty row. The CHECK on `categories` guarantees at least one of the two is present,
/// so the empty string is unreachable.
String categoryDisplayName({required String? name, required String? nameKey, required GPLocaleBase l10n}) {
  if (name != null && name.isNotEmpty) return name;
  if (nameKey == null) return '';

  return DefaultCategory.fromNameKey(nameKey)?.nameIn(l10n) ?? nameKey;
}
