import '../localization/locale_base/locale_base.dart';
import 'failure.dart';

/// Kept out of `failure.dart` so `domain/` never sees localization (ADR-0004). No wildcard: a new failure or code must not compile without a message.
extension GPFailureExtension on GPFailure {
  String getMessage(GPLocaleBase locale) {
    final errorLocale = locale.error;
    return switch (this) {
      GPNetworkFailure() => errorLocale.network,
      GPTimeoutFailure() => errorLocale.timeout,
      GPAuthenticationFailure() => errorLocale.authentication,
      GPAuthorizationFailure() => errorLocale.authorization,
      GPRateLimitedFailure() => errorLocale.rateLimited,
      GPBackendUnavailableFailure() => errorLocale.backendUnavailable,
      GPValidationFailure(:final code) => switch (code) {
        GPValidationCode.accountNameEmpty => errorLocale.validationAccountNameEmpty,
        GPValidationCode.accountNameTooLong => errorLocale.validationAccountNameTooLong,
        GPValidationCode.accountHasTransactions => errorLocale.validationAccountHasTransactions,
        GPValidationCode.categoryNameEmpty => errorLocale.validationCategoryNameEmpty,
        GPValidationCode.categoryNameTooLong => errorLocale.validationCategoryNameTooLong,
        GPValidationCode.transactionAmountNotPositive => errorLocale.validationTransactionAmountNotPositive,
        GPValidationCode.transactionDestinationMissing => errorLocale.validationTransactionDestinationMissing,
        GPValidationCode.transactionDestinationSameAsSource => errorLocale.validationTransactionDestinationSameAsSource,
        GPValidationCode.transactionNoteTooLong => errorLocale.validationTransactionNoteTooLong,
        GPValidationCode.transactionCurrencyMismatch => errorLocale.validationTransactionCurrencyMismatch,
        GPValidationCode.transactionTransferCurrenciesDiffer => errorLocale.validationTransactionTransferCurrenciesDiffer,
        GPValidationCode.transactionCategoryTypeMismatch => errorLocale.validationTransactionCategoryTypeMismatch,
        GPValidationCode.transactionDateInFuture => errorLocale.validationTransactionDateInFuture,
        GPValidationCode.authInvalidCredentials => errorLocale.validationAuthInvalidCredentials,
        GPValidationCode.authEmailEmpty => errorLocale.validationAuthEmailEmpty,
        GPValidationCode.authEmailInvalid => errorLocale.validationAuthEmailInvalid,
        GPValidationCode.authEmailTaken => errorLocale.validationAuthEmailTaken,
        GPValidationCode.authPasswordEmpty => errorLocale.validationAuthPasswordEmpty,
        GPValidationCode.authPasswordTooShort => errorLocale.validationAuthPasswordTooShort,
        GPValidationCode.authPasswordWeak => errorLocale.validationAuthPasswordWeak,
      },
      GPConflictFailure() => errorLocale.conflict,
      GPNotFoundFailure() => errorLocale.notFound,
      GPDatabaseFailure() => errorLocale.database,
      GPUnknownFailure() => errorLocale.unknown,
    };
  }
}
