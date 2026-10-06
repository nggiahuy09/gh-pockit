part of 'locale_base.dart';

/// Seeded default categories only, mapped from `name_key` in the categories feature. A user's own category keeps the name they typed.
abstract class GPLocaleBaseCategories {
  const GPLocaleBaseCategories();

  String get food;
  String get transport;
  String get shopping;
  String get bills;
  String get housing;
  String get health;
  String get entertainment;
  String get education;
  String get otherExpense;
  String get salary;
  String get otherIncome;
}
