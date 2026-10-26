import 'package:flutter/material.dart';

import '../../../core/localization/locale_base/locale_base.dart';
import '../domain/entities/account_type.dart';

extension AccountTypeExtension on AccountType {
  IconData get icon => switch (this) {
    AccountType.cash => Icons.payments_outlined,
    AccountType.bank => Icons.account_balance_outlined,
    AccountType.eWallet => Icons.account_balance_wallet_outlined,
    AccountType.creditCard => Icons.credit_card_outlined,
    AccountType.other => Icons.category_outlined,
  };

  String getTitle(GPLocaleBase locale) {
    final accountsLocale = locale.accounts;
    return switch (this) {
      AccountType.cash => accountsLocale.typeCash,
      AccountType.bank => accountsLocale.typeBank,
      AccountType.eWallet => accountsLocale.typeEWallet,
      AccountType.creditCard => accountsLocale.typeCreditCard,
      AccountType.other => accountsLocale.typeOther,
    };
  }
}
