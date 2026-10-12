import 'package:ghpockit/core/error/failure.dart';

/// The fields a refused save can point at (ADR-0016). Type, currency and opening balance have no rule that can refuse them.
enum AccountFormField { name }

/// The field a refused save is about, or null when it is about none and belongs in the banner. No wildcard: a new validation code must not compile
/// until it is placed.
AccountFormField? accountFormFieldOf(GPFailure failure) => switch (failure) {
  GPValidationFailure(:final code) => switch (code) {
    GPValidationCode.accountNameEmpty || GPValidationCode.accountNameTooLong => AccountFormField.name,
    // Refuses a delete, which this form does not offer.
    GPValidationCode.accountHasTransactions => null,
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
  _ => null,
};
