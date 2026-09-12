import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';

/// Turns a failure type into a sentence in the active language.
///
/// The other half of ADR-0004: `GPFailure` carries a type, and this is the single place that decides what the user reads for it.
///
/// Kept in its own file rather than inside `failure.dart` so the failure types stay importable with no localization dependency at all — `domain/`
/// returns a `GPFailure` and must never see a `GPLocaleBase`. An extension rather than a method on `GPFailure` for the same reason: the mapping is
/// presentation's job, so it does not belong on the type it maps.
///
/// The `switch` is exhaustive over a sealed type with no `default` branch, which is the entire value of this file. Adding a subtype to
/// [GPFailure] without deciding what the user reads for it does not compile. Scattering `if (failure is GPNetworkFailure)` across pages would give
/// the same behaviour today and none of that guarantee tomorrow.
extension GPFailureMessage on GPFailure {
  String message(GPLocaleBase l10n) => switch (this) {
    GPNetworkFailure() => l10n.error.network,
    GPTimeoutFailure() => l10n.error.timeout,
    GPAuthenticationFailure() => l10n.error.authentication,
    GPAuthorizationFailure() => l10n.error.authorization,
    GPValidationFailure() => l10n.error.validation,
    GPConflictFailure() => l10n.error.conflict,
    GPDatabaseFailure() => l10n.error.database,
    GPUnknownFailure() => l10n.error.unknown,
  };
}
