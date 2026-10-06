import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';

/// Kept out of `failure.dart` so `domain/` never sees localization (ADR-0004). No wildcard in either switch: a new failure or validation code must not
/// compile without a message.
extension GPFailureMessage on GPFailure {
  String message(GPLocaleBase l10n) => switch (this) {
    GPNetworkFailure() => l10n.error.network,
    GPTimeoutFailure() => l10n.error.timeout,
    GPAuthenticationFailure() => l10n.error.authentication,
    GPAuthorizationFailure() => l10n.error.authorization,
    GPValidationFailure(:final code) => switch (code) {
      GPValidationCode.accountNameEmpty => l10n.error.validationAccountNameEmpty,
      GPValidationCode.accountNameTooLong => l10n.error.validationAccountNameTooLong,
      GPValidationCode.accountHasTransactions => l10n.error.validationAccountHasTransactions,
      GPValidationCode.categoryNameEmpty => l10n.error.validationCategoryNameEmpty,
      GPValidationCode.categoryNameTooLong => l10n.error.validationCategoryNameTooLong,
      GPValidationCode.transactionAmountNotPositive => l10n.error.validationTransactionAmountNotPositive,
      GPValidationCode.transactionDestinationMissing => l10n.error.validationTransactionDestinationMissing,
      GPValidationCode.transactionDestinationSameAsSource => l10n.error.validationTransactionDestinationSameAsSource,
      GPValidationCode.transactionNoteTooLong => l10n.error.validationTransactionNoteTooLong,
      GPValidationCode.transactionCurrencyMismatch => l10n.error.validationTransactionCurrencyMismatch,
      GPValidationCode.transactionTransferCurrenciesDiffer => l10n.error.validationTransactionTransferCurrenciesDiffer,
      GPValidationCode.transactionCategoryTypeMismatch => l10n.error.validationTransactionCategoryTypeMismatch,
    },
    GPConflictFailure() => l10n.error.conflict,
    GPNotFoundFailure() => l10n.error.notFound,
    GPDatabaseFailure() => l10n.error.database,
    GPUnknownFailure() => l10n.error.unknown,
  };
}
