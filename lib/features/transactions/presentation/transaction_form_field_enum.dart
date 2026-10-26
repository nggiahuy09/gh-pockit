import '../../../core/error/failure.dart';

/// The fields a refused save can point at (ADR-0016).
enum TransactionFormField {
  amount,
  account,
  destination,
  category,
  note;

  /// Null when the failure is about no field and belongs in the banner. No wildcard: a new validation code must not compile until it is placed.
  static TransactionFormField? fromFailure(GPFailure failure) => switch (failure) {
    GPValidationFailure(:final code) => switch (code) {
      GPValidationCode.accountNameEmpty ||
      GPValidationCode.accountNameTooLong ||
      GPValidationCode.accountHasTransactions ||
      GPValidationCode.categoryNameEmpty ||
      GPValidationCode.categoryNameTooLong => null,
      GPValidationCode.transactionAmountNotPositive => TransactionFormField.amount,
      // The source was picked first, and the picker offers only destinations it can pair with: the destination is what fixes these.
      GPValidationCode.transactionDestinationMissing || GPValidationCode.transactionDestinationSameAsSource => TransactionFormField.destination,
      GPValidationCode.transactionNoteTooLong => TransactionFormField.note,
      // The account's currency changed under the form: picking the account again is the fix.
      GPValidationCode.transactionCurrencyMismatch => TransactionFormField.account,
      GPValidationCode.transactionTransferCurrenciesDiffer => TransactionFormField.destination,
      GPValidationCode.transactionCategoryTypeMismatch => TransactionFormField.category,
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
