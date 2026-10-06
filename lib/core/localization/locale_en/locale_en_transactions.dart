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
}
