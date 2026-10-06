import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';

extension AccountTypeLabel on AccountType {
  String labelIn(GPLocaleBase l10n) {
    final accounts = l10n.accounts;

    return switch (this) {
      AccountType.cash => accounts.typeCash,
      AccountType.bank => accounts.typeBank,
      AccountType.eWallet => accounts.typeEWallet,
      AccountType.creditCard => accounts.typeCreditCard,
      AccountType.other => accounts.typeOther,
    };
  }
}
