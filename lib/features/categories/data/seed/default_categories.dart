import 'package:ghpockit/features/categories/domain/entities/category_type.dart';

/// Keys, never names: the text is resolved from the active locale at render time (ADR-0004).
enum DefaultCategory {
  food(nameKey: 'category.food', type: CategoryType.expense, iconKey: 'food'),
  transport(nameKey: 'category.transport', type: CategoryType.expense, iconKey: 'transport'),
  shopping(nameKey: 'category.shopping', type: CategoryType.expense, iconKey: 'shopping'),
  bills(nameKey: 'category.bills', type: CategoryType.expense, iconKey: 'bills'),
  housing(nameKey: 'category.housing', type: CategoryType.expense, iconKey: 'housing'),
  health(nameKey: 'category.health', type: CategoryType.expense, iconKey: 'health'),
  entertainment(nameKey: 'category.entertainment', type: CategoryType.expense, iconKey: 'entertainment'),
  education(nameKey: 'category.education', type: CategoryType.expense, iconKey: 'education'),
  otherExpense(nameKey: 'category.other_expense', type: CategoryType.expense, iconKey: 'other'),

  salary(nameKey: 'category.salary', type: CategoryType.income, iconKey: 'salary'),
  otherIncome(nameKey: 'category.other_income', type: CategoryType.income, iconKey: 'other');

  const DefaultCategory({required this.nameKey, required this.type, required this.iconKey});

  /// Stored in `categories.name_key` and hashed into the seeded id, so a shipped key never changes.
  final String nameKey;

  final CategoryType type;
  final String iconKey;

  /// Null for a key this build does not ship, e.g. one seeded by a newer build.
  static DefaultCategory? fromNameKey(String nameKey) {
    for (final category in values) {
      if (category.nameKey == nameKey) return category;
    }

    return null;
  }
}
