import '../../domain/entities/category_type.dart';

/// Keys, never names: the text is resolved from the active locale at render time (ADR-0004).
enum DefaultCategory {
  food(CategoryType.expense, 'food', 'category.food'),
  transport(CategoryType.expense, 'transport', 'category.transport'),
  shopping(CategoryType.expense, 'shopping', 'category.shopping'),
  bills(CategoryType.expense, 'bills', 'category.bills'),
  housing(CategoryType.expense, 'housing', 'category.housing'),
  health(CategoryType.expense, 'health', 'category.health'),
  entertainment(CategoryType.expense, 'entertainment', 'category.entertainment'),
  education(CategoryType.expense, 'education', 'category.education'),
  otherExpense(CategoryType.expense, 'other', 'category.other_expense'),

  salary(CategoryType.income, 'salary', 'category.salary'),
  otherIncome(CategoryType.income, 'other', 'category.other_income');

  const DefaultCategory(this.type, this.iconKey, this.nameKey);

  final CategoryType type;
  final String iconKey;

  /// Hashed into the seeded id, so a shipped key never changes.
  final String nameKey;

  static DefaultCategory? fromNameKey(String nameKey) => values.where((category) => category.nameKey == nameKey).firstOrNull;
}
