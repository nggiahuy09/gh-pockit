part of 'locale_en.dart';

final class GPLocaleEnError implements GPLocaleBaseError {
  const GPLocaleEnError();

  @override
  String get network => 'No internet connection.';

  @override
  String get timeout => 'The request timed out.';

  @override
  String get authentication => 'Your session has expired. Please sign in again.';

  @override
  String get authorization => 'You do not have permission to do that.';

  @override
  String get validationAccountNameEmpty => "Account name can't be empty.";

  @override
  String get validationAccountNameTooLong => 'Account name is too long.';

  @override
  String get validationCategoryNameEmpty => "Category name can't be empty.";

  @override
  String get validationCategoryNameTooLong => 'Category name is too long.';

  @override
  String get validationTransactionAmountNotPositive => 'Amount must be greater than zero.';

  @override
  String get validationTransactionDestinationMissing => 'Choose an account to transfer to.';

  @override
  String get validationTransactionDestinationSameAsSource => "Can't transfer to the same account.";

  @override
  String get validationTransactionNoteTooLong => 'Note is too long.';

  @override
  String get validationTransactionCurrencyMismatch => "The amount's currency doesn't match the account.";

  @override
  String get validationTransactionTransferCurrenciesDiffer => 'Both accounts in a transfer must use the same currency.';

  @override
  String get conflict => 'This item was changed on another device.';

  @override
  String get notFound => 'That item no longer exists.';

  @override
  String get database => 'Could not read local data.';

  @override
  String get unknown => 'Something went wrong.';

  @override
  String get routeNotFoundTitle => 'Page not found';

  @override
  String get routeNotFoundMessage => 'That link does not point anywhere in Pockit.';
}
