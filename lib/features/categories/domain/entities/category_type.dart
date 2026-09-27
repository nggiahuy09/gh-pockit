/// Whether a category groups money going out or money coming in — blueprint §Categories, "Income/expense type".
///
/// A closed set rather than a free-text label for the same reason as `AccountType`: W6's picker splits the list in two, and W7's "spending by category"
/// aggregate is meaningless if an income category can drift into the expense half through a typo.
///
/// **Transfers are deliberately absent.** A transfer moves money between two accounts the user already owns, so it belongs to no spending category at all —
/// `TransactionType` at W4 carries `transfer`, and a transfer row simply has no `category_id`. Adding a third value here would invite exactly the
/// double-counting W6 T5 exists to prevent.
///
/// Pulled forward from T6 into T5 because the seeder has to state a type for every default category, and a data layer inventing the strings `'expense'`
/// and `'income'` by hand is the stored vocabulary living in two places. Same move, same reason, as `Money` arriving in W2 T5.
///
/// [storageValue] is explicit and never derived from [name] — see `AccountType` for the full argument against drift's `textEnum`.
enum CategoryType {
  expense('expense'),
  income('income');

  const CategoryType(this.storageValue);

  /// The exact string in the `categories.type` column.
  final String storageValue;

  /// The inverse of [storageValue], or null when [value] is not one of ours — a corrupt row or one written by a newer build, which is the mapper's
  /// `GPDatabaseFailure` to raise at T6 rather than a value to guess at.
  static CategoryType? fromStorage(String value) {
    for (final type in values) {
      if (type.storageValue == value) return type;
    }

    return null;
  }
}
