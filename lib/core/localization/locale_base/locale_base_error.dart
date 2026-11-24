part of 'locale_base.dart';

abstract class GPLocaleBaseError {
  const GPLocaleBaseError();

  String get network;
  String get timeout;
  String get authentication;
  String get authorization;
  String get rateLimited;
  String get backendUnavailable;

  /// No limits in the copy ("max 100 characters"): they live in the entities, and the form shows them with a live counter.
  String get validationAccountNameEmpty;
  String get validationAccountNameTooLong;
  String get validationAccountHasTransactions;
  String get validationCategoryNameEmpty;
  String get validationCategoryNameTooLong;
  String get validationTransactionAmountNotPositive;
  String get validationTransactionDestinationMissing;
  String get validationTransactionDestinationSameAsSource;
  String get validationTransactionNoteTooLong;
  String get validationTransactionCurrencyMismatch;
  String get validationTransactionTransferCurrenciesDiffer;
  String get validationTransactionCategoryTypeMismatch;
  String get validationTransactionDateInFuture;
  String get validationAuthInvalidCredentials;
  String get validationAuthEmailEmpty;
  String get validationAuthEmailInvalid;
  String get validationAuthEmailTaken;
  String get validationAuthPasswordEmpty;
  String get validationAuthPasswordTooShort;
  String get validationAuthPasswordWeak;
  String get validationAuthDeviceOwnedByAnotherAccount;
  String get validationSignOutUnsyncedChanges;
  String get conflict;
  String get notFound;
  String get database;
  String get unknown;
  String get routeNotFoundTitle;
  String get routeNotFoundBody;

  /// Shown before the app itself, when the database will not open (ADR-0030). Both bodies say the data is still there.
  String get databaseTooNewTitle;
  String get databaseTooNewBody;
  String get databaseOpenFailedTitle;
  String get databaseOpenFailedBody;

  /// The misconfigured-build screen (ADR-0038); the problem code follows the body.
  String get backendConfigInvalidTitle;
  String get backendConfigInvalidBody;
}
