import '../../../core/error/failure.dart';

/// The fields a refused sign-in or sign-up can point at (ADR-0016).
enum AuthFormField {
  email,
  password;

  /// Null when the failure is about no field and belongs in the banner: wrong credentials, a rate limit, the network. No wildcard: a new
  /// validation code must not compile until it is placed.
  static AuthFormField? fromFailure(GPFailure failure) => switch (failure) {
    GPValidationFailure(:final code) => switch (code) {
      GPValidationCode.authEmailEmpty || GPValidationCode.authEmailInvalid || GPValidationCode.authEmailTaken => AuthFormField.email,
      GPValidationCode.authPasswordEmpty || GPValidationCode.authPasswordTooShort || GPValidationCode.authPasswordWeak => AuthFormField.password,
      GPValidationCode.accountNameEmpty ||
      GPValidationCode.accountNameTooLong ||
      GPValidationCode.accountHasTransactions ||
      GPValidationCode.categoryNameEmpty ||
      GPValidationCode.categoryNameTooLong ||
      GPValidationCode.transactionAmountNotPositive ||
      GPValidationCode.transactionDestinationMissing ||
      GPValidationCode.transactionDestinationSameAsSource ||
      GPValidationCode.transactionNoteTooLong ||
      GPValidationCode.transactionCurrencyMismatch ||
      GPValidationCode.transactionTransferCurrenciesDiffer ||
      GPValidationCode.transactionCategoryTypeMismatch ||
      GPValidationCode.transactionDateInFuture ||
      GPValidationCode.authInvalidCredentials => null,
    },
    GPNetworkFailure() ||
    GPTimeoutFailure() ||
    GPAuthenticationFailure() ||
    GPAuthorizationFailure() ||
    GPRateLimitedFailure() ||
    GPBackendUnavailableFailure() ||
    GPConflictFailure() ||
    GPNotFoundFailure() ||
    GPDatabaseFailure() ||
    GPUnknownFailure() => null,
  };
}
