import '../../../core/error/failure.dart';

/// The fields a refused save can point at (ADR-0016).
enum AccountFormField {
  name;

  /// Null when the failure is about no field and belongs in the banner. No wildcard: a new validation code must not compile until it is placed.
  static AccountFormField? fromFailure(GPFailure failure) => switch (failure) {
    GPValidationFailure(:final code) => switch (code) {
      GPValidationCode.accountNameEmpty || GPValidationCode.accountNameTooLong => AccountFormField.name,
      GPValidationCode.accountHasTransactions ||
      GPValidationCode.categoryNameEmpty ||
      GPValidationCode.categoryNameTooLong ||
      GPValidationCode.transactionAmountNotPositive ||
      GPValidationCode.transactionDestinationMissing ||
      GPValidationCode.transactionDestinationSameAsSource ||
      GPValidationCode.transactionNoteTooLong ||
      GPValidationCode.transactionCurrencyMismatch ||
      GPValidationCode.transactionTransferCurrenciesDiffer ||
      GPValidationCode.transactionCategoryTypeMismatch => null,
    },
    GPNetworkFailure() ||
    GPTimeoutFailure() ||
    GPAuthenticationFailure() ||
    GPAuthorizationFailure() ||
    GPConflictFailure() ||
    GPNotFoundFailure() ||
    GPDatabaseFailure() ||
    GPUnknownFailure() => null,
  };
}
