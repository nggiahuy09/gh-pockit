part of 'locale_en.dart';

final class GPLocaleEnTransactions implements GPLocaleBaseTransactions {
  const GPLocaleEnTransactions();

  @override
  String get title => 'Transactions';

  @override
  String get typeExpense => 'Expense';

  @override
  String get typeIncome => 'Income';

  @override
  String get typeTransfer => 'Transfer';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get add => 'Add transaction';

  @override
  String get edit => 'Edit transaction';

  @override
  String get emptyTitle => 'No transactions yet';

  @override
  String get emptyMessage => 'Your expenses, income and transfers will show up here.';

  @override
  String get errorMessage => 'The list comes back by itself the next time data is saved.';

  @override
  String unreadable(int count) => count == 1 ? "1 transaction can't be shown" : "$count transactions can't be shown";

  @override
  String get loading => 'Loading transactions';

  @override
  String get loadingMore => 'Loading more';

  @override
  String get fieldType => 'Type';

  @override
  String get fieldAmount => 'Amount';

  @override
  String get fieldAccount => 'Account';

  @override
  String get fieldCategory => 'Category';

  @override
  String get fieldDate => 'Date';

  @override
  String get fieldNote => 'Note';

  @override
  String get uncategorised => 'Uncategorised';

  @override
  String get save => 'Save';

  @override
  String get noAccountsTitle => 'Add an account first';

  @override
  String get noAccountsMessage => 'A transaction needs an account to come from or go to.';
}
