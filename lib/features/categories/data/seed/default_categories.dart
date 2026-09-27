import 'package:ghpockit/features/categories/domain/entities/category_type.dart';

/// The categories every new install starts with (W3 T5).
///
/// **A key and a type, never a name.** Each entry carries the translation key that lands in `categories.name_key`; the text a user reads is looked up at
/// render time from the active locale, so switching language switches the category list too (ADR-0004). This enum is the single place the set is declared,
/// which is what makes the compiler enforce that: adding a value here makes the exhaustive switch in `DefaultCategoryName` incomplete, which fails to compile
/// until both `GPLocaleEn` and `GPLocaleVi` carry the new string.
///
/// **Eleven, not fifty.** A default list is a guess about a stranger's life and every wrong guess is a row they have to delete before the app is usable.
/// These are the ones a Vietnamese personal budget almost always has; anything more specific is better as the first category the user creates themselves.
///
/// [iconKey] is a semantic key, resolved against an icon set W6 builds. `color_key` is deliberately absent from the seed: the theme already carries `income`
/// and `expense` colours, so colouring by type is the sensible default, and a per-category colour is a choice the user makes rather than one we guess. The
/// column exists for that choice — see `categories_table.dart`.
enum DefaultCategory {
  food(nameKey: 'category.food', type: CategoryType.expense, iconKey: 'food'),
  transport(nameKey: 'category.transport', type: CategoryType.expense, iconKey: 'transport'),
  shopping(nameKey: 'category.shopping', type: CategoryType.expense, iconKey: 'shopping'),
  bills(nameKey: 'category.bills', type: CategoryType.expense, iconKey: 'bills'),
  housing(nameKey: 'category.housing', type: CategoryType.expense, iconKey: 'housing'),
  health(nameKey: 'category.health', type: CategoryType.expense, iconKey: 'health'),
  entertainment(nameKey: 'category.entertainment', type: CategoryType.expense, iconKey: 'entertainment'),
  education(nameKey: 'category.education', type: CategoryType.expense, iconKey: 'education'),

  /// The escape hatch on the expense side, for the same reason `AccountType.other` exists: without it, an unclassifiable expense gets filed under whichever
  /// category is closest, which is worse data than an honest "other".
  otherExpense(nameKey: 'category.other_expense', type: CategoryType.expense, iconKey: 'other'),

  salary(nameKey: 'category.salary', type: CategoryType.income, iconKey: 'salary'),
  otherIncome(nameKey: 'category.other_income', type: CategoryType.income, iconKey: 'other');

  const DefaultCategory({required this.nameKey, required this.type, required this.iconKey});

  /// What goes in `categories.name_key`. Dotted and lower snake case, matching the `error.*` keys ADR-0004 already established.
  final String nameKey;

  final CategoryType type;

  /// Semantic, not a code point and not a Material identifier: a stored code point means nothing once the icon font changes.
  final String iconKey;

  /// The inverse of [nameKey], or null for a key we no longer ship.
  ///
  /// Null rather than a throw, because this is read from a row. A category seeded by a newer build and then opened on an older one has a key this version
  /// has never heard of, and the honest answer is "I cannot name this", which `categoryDisplayName` renders as the user's own name or as the raw key — not a
  /// crash, and not a wrong name.
  static DefaultCategory? fromNameKey(String nameKey) {
    for (final category in values) {
      if (category.nameKey == nameKey) return category;
    }

    return null;
  }
}
