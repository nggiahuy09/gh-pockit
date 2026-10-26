part of 'locale_base.dart';

abstract class GPLocaleBaseError {
  const GPLocaleBaseError();

  String get network;
  String get timeout;
  String get authentication;
  String get authorization;

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
  String get conflict;
  String get notFound;
  String get database;
  String get unknown;
  String get routeNotFoundTitle;
  String get routeNotFoundBody;
}
