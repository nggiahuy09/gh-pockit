part of 'locale_base.dart';

abstract class GPLocaleBaseTransactions {
  const GPLocaleBaseTransactions();

  String get title;
  String get typeExpense;
  String get typeIncome;
  String get typeTransfer;
  String get today;
  String get yesterday;
  String get add;
  String get emptyTitle;
  String get emptyMessage;
  String get errorMessage;
  String unreadable(int count);
  String get loading;
  String get loadingMore;
  String get fieldType;
  String get fieldAmount;
  String get fieldAccount;
  String get fieldCategory;
  String get fieldDate;
  String get fieldNote;

  /// A transaction with no category, or one whose category was deleted (ADR-0010).
  String get uncategorised;

  String get save;

  /// The form's empty state: nothing to write to until an account exists.
  String get noAccountsTitle;
  String get noAccountsMessage;
}
