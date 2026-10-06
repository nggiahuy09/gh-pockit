import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/money/money_formatter.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

extension TransactionTypeLabel on TransactionType {
  String labelIn(GPLocaleBase l10n) {
    final transactions = l10n.transactions;

    return switch (this) {
      TransactionType.expense => transactions.typeExpense,
      TransactionType.income => transactions.typeIncome,
      TransactionType.transfer => transactions.typeTransfer,
    };
  }
}

extension TransactionLabels on TransactionEntity {
  /// Category and account names arrive with W7's join.
  String titleIn(GPLocaleBase l10n) => note ?? type.labelIn(l10n);

  String amountLabel(GPMoneyFormatter formatter) => switch (type) {
    TransactionType.expense => formatter.format(-amount),
    TransactionType.income => '+${formatter.format(amount)}',
    TransactionType.transfer => formatter.format(amount),
  };
}
