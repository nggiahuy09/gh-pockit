import '../../../core/localization/locale_base/locale_base.dart';
import '../domain/entities/transaction_type.dart';

extension TransactionTypeExtension on TransactionType {
  String getTitle(GPLocaleBase locale) {
    final transactionsLocale = locale.transactions;
    return switch (this) {
      TransactionType.expense => transactionsLocale.typeExpense,
      TransactionType.income => transactionsLocale.typeIncome,
      TransactionType.transfer => transactionsLocale.typeTransfer,
    };
  }
}
