import 'package:ghpockit/core/localization/locale.dart';

part 'locale_base_root.dart';
part 'locale_base_home.dart';
part 'locale_base_accounts.dart';
part 'locale_base_transactions.dart';
part 'locale_base_budgets.dart';
part 'locale_base_settings.dart';
part 'locale_base_error.dart';

/// Every user-facing string in the app, as a contract.
///
/// Hand-written rather than generated from ARB files (ADR-0004). The property that buys: **the analyzer is the completeness check.** A new getter here
/// does not compile until both `GPLocaleEn` and `GPLocaleVi` implement it, so a shipped screen cannot fall back to English because somebody forgot a
/// key. With ARB a missing key is a runtime surprise.
///
/// Strings are grouped by feature, one `part` file per group, mirroring `lib/features/`. A section stays small enough to read; the group a string
/// belongs to is the folder it will be used from.
///
/// Implementations are `const`: a locale holds no state, so switching language allocates nothing.
abstract class GPLocaleBase {
  const GPLocaleBase();

  /// Which locale this is. Lets a widget read the active language off the strings it already has, without reaching for `GPLocalization`.
  GPLocale get locale;

  GPLocaleBaseRoot get root;
  GPLocaleBaseHome get home;
  GPLocaleBaseAccounts get accounts;
  GPLocaleBaseTransactions get transactions;
  GPLocaleBaseBudgets get budgets;
  GPLocaleBaseSettings get settings;
  GPLocaleBaseError get error;
}
