import 'package:ghpockit/core/error/failure.dart';

/// The fields a refused save can point at (ADR-0016). The type and the date have no rule that can refuse them.
enum TransactionFormField { amount, account, category, note }

/// The field a refused save is about, or null when it is about none (a conflict, a read failure, a row gone) and belongs in the banner. No wildcard:
/// a new validation code must not compile until it is placed.
TransactionFormField? transactionFormFieldOf(GPFailure failure) => switch (failure) {
  GPValidationFailure(:final code) => switch (code) {
    GPValidationCode.transactionAmountNotPositive => TransactionFormField.amount,
    // The account's currency changed under the form: picking the account again is the fix.
    GPValidationCode.transactionCurrencyMismatch => TransactionFormField.account,
    GPValidationCode.transactionCategoryTypeMismatch => TransactionFormField.category,
    GPValidationCode.transactionNoteTooLong => TransactionFormField.note,
    // The form offers no transfer yet, so no destination field to point at.
    GPValidationCode.transactionDestinationMissing || GPValidationCode.transactionDestinationSameAsSource || GPValidationCode.transactionTransferCurrenciesDiffer => null,
    GPValidationCode.accountNameEmpty ||
    GPValidationCode.accountNameTooLong ||
    GPValidationCode.accountHasTransactions ||
    GPValidationCode.categoryNameEmpty ||
    GPValidationCode.categoryNameTooLong => null,
  },
  _ => null,
};
