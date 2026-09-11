import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';

part 'locale_vi_root.dart';
part 'locale_vi_home.dart';
part 'locale_vi_accounts.dart';
part 'locale_vi_transactions.dart';
part 'locale_vi_budgets.dart';
part 'locale_vi_settings.dart';
part 'locale_vi_error.dart';

/// Vietnamese strings.
final class GPLocaleVi implements GPLocaleBase {
  const GPLocaleVi();

  @override
  GPLocale get locale => GPLocale.vi;

  @override
  GPLocaleBaseRoot get root => const GPLocaleViRoot();

  @override
  GPLocaleBaseHome get home => const GPLocaleViHome();

  @override
  GPLocaleBaseAccounts get accounts => const GPLocaleViAccounts();

  @override
  GPLocaleBaseTransactions get transactions => const GPLocaleViTransactions();

  @override
  GPLocaleBaseBudgets get budgets => const GPLocaleViBudgets();

  @override
  GPLocaleBaseSettings get settings => const GPLocaleViSettings();

  @override
  GPLocaleBaseError get error => const GPLocaleViError();
}
