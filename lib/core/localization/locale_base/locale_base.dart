import 'package:ghpockit/core/localization/locale.dart';

part 'locale_base_root.dart';
part 'locale_base_home.dart';
part 'locale_base_accounts.dart';
part 'locale_base_transactions.dart';
part 'locale_base_budgets.dart';
part 'locale_base_categories.dart';
part 'locale_base_settings.dart';
part 'locale_base_error.dart';

/// Hand-written, not ARB (ADR-0004): keep every getter abstract, so a new string does not compile until both languages implement it.
abstract class GPLocaleBase {
  const GPLocaleBase();

  GPLocale get locale;

  GPLocaleBaseRoot get root;
  GPLocaleBaseHome get home;
  GPLocaleBaseAccounts get accounts;
  GPLocaleBaseTransactions get transactions;
  GPLocaleBaseBudgets get budgets;
  GPLocaleBaseCategories get categories;
  GPLocaleBaseSettings get settings;
  GPLocaleBaseError get error;
}
