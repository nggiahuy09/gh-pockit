import '../../../core/localization/locale_base/locale_base.dart';
import '../../../core/widgets/money_text.dart';
import '../domain/entities/transaction_entity.dart';
import '../domain/entities/transaction_type.dart';
import 'transaction_type_extension.dart';

extension TransactionEntityExtension on TransactionEntity {
  /// A transfer moves money between the user's own accounts, so it is neither spent nor earned.
  GPMoneyTone get moneyTone => switch (type) {
    TransactionType.expense => GPMoneyTone.expense,
    TransactionType.income => GPMoneyTone.income,
    TransactionType.transfer => GPMoneyTone.neutral,
  };

  String getTitle(GPLocaleBase locale) => note ?? type.getTitle(locale);
}
