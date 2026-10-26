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

  String get edit;

  String get emptyTitle;

  String get emptyBody;

  String get errorBody;

  String get loading;

  String get loadingMore;

  String get fieldType;

  String get fieldAmount;

  String get fieldAccount;

  String get fieldFromAccount;

  String get fieldToAccount;

  String get noDestinationMessage;

  String get fieldCategory;

  String get fieldDate;

  String get fieldNote;

  String get uncategorised;

  String get save;

  String get delete;

  String get deleteConfirmTitle;

  String get deleted;

  String get undo;

  String get noAccountsTitle;

  String get noAccountsBody;

  String unreadable(int count);
}
