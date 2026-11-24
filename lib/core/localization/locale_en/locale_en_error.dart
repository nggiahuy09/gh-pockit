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
  String get rateLimited => 'Too many attempts. Wait a few minutes and try again.';

  @override
  String get backendUnavailable => 'This version of Pockit works offline only, so there is no account to sign in to.';

  @override
  String get validationAccountNameEmpty => "Account name can't be empty.";

  @override
  String get validationAccountNameTooLong => 'Account name is too long.';

  @override
  String get validationAccountHasTransactions => "This account has transactions, so it can't be deleted. Archive it instead to hide it and keep its history.";

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
  String get validationTransactionCategoryTypeMismatch => 'Pick an expense category for an expense, and an income category for income.';

  @override
  String get validationTransactionDateInFuture => 'Pick today or an earlier day.';

  @override
  String get validationAuthInvalidCredentials => 'The email or password is incorrect.';

  @override
  String get validationAuthEmailEmpty => 'Enter your email.';

  @override
  String get validationAuthEmailInvalid => 'Enter a valid email address.';

  @override
  String get validationAuthEmailTaken => 'An account with this email already exists.';

  @override
  String get validationAuthPasswordEmpty => 'Enter your password.';

  @override
  String get validationAuthPasswordTooShort => 'Password is too short.';

  @override
  String get validationAuthPasswordWeak => 'Choose a stronger password.';

  @override
  String get validationSignOutUnsyncedChanges => 'Some changes are not backed up yet, so signing out would delete them.';

  @override
  String get validationAuthDeviceOwnedByAnotherAccount => "This device still holds another account's data. Sign out of that account first.";

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
  String get routeNotFoundBody => 'That link does not point anywhere in Pockit.';

  @override
  String get databaseTooNewTitle => 'Update Pockit to open your data';

  @override
  String get databaseTooNewBody => 'Your data was saved by a newer version of Pockit than this one. Nothing has been changed or deleted. Install the latest version to carry on.';

  @override
  String get databaseOpenFailedTitle => 'Pockit could not open your data';

  @override
  String get databaseOpenFailedBody => 'Your data is still on this device, and nothing was deleted. Close the app fully and open it again. If this keeps happening, update Pockit.';

  @override
  String get backendConfigInvalidTitle => 'This build is misconfigured';

  @override
  String get backendConfigInvalidBody => 'Its env file does not match its flavor, or is incomplete. Rebuild with the right --dart-define-from-file.';
}
