part of 'locale_base.dart';

/// Names for the categories the app seeds (W3 T5).
///
/// These are strings and nothing else: the mapping from a stored `name_key` to one of these getters lives in the categories feature, because `core/` holds
/// no feature's rules (§3). What lives here is the guarantee that every one of them exists in both languages — a getter added below does not compile until
/// `GPLocaleEn` and `GPLocaleVi` both answer it, which is the property ADR-0004 bought instead of ARB files.
///
/// Only the **default** categories appear here. A category the user creates carries its own text in `categories.name`, and translating a name somebody typed
/// would be absurd.
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
