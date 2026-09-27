import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';

/// What an [AccountType] is called in the active language.
///
/// The same mechanism as `DefaultCategoryName` (ADR-0004): exhaustive, no `default` branch, so a sixth account type stops the app compiling until both
/// `GPLocaleEn` and `GPLocaleVi` name it.
///
/// **In presentation, and never [AccountType.storageValue].** The stored value is a vocabulary for SQLite and the wire — `e_wallet` — and it is kept
/// stable precisely so it can be renamed on screen without a migration. Rendering it directly would tie the two together again.
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
