import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';

part 'locale_en_root.dart';
part 'locale_en_home.dart';
part 'locale_en_accounts.dart';
part 'locale_en_transactions.dart';
part 'locale_en_budgets.dart';
part 'locale_en_settings.dart';
part 'locale_en_error.dart';

/// English strings.
final class GPLocaleEn implements GPLocaleBase {
  const GPLocaleEn();

  @override
  GPLocale get locale => GPLocale.en;

  @override
  GPLocaleBaseRoot get root => const GPLocaleEnRoot();

  @override
  GPLocaleBaseHome get home => const GPLocaleEnHome();

  @override
  GPLocaleBaseAccounts get accounts => const GPLocaleEnAccounts();

  @override
  GPLocaleBaseTransactions get transactions => const GPLocaleEnTransactions();

  @override
  GPLocaleBaseBudgets get budgets => const GPLocaleEnBudgets();

  @override
  GPLocaleBaseSettings get settings => const GPLocaleEnSettings();

  @override
  GPLocaleBaseError get error => const GPLocaleEnError();
}
