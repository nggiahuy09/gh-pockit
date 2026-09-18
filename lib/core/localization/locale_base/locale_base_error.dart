part of 'locale_base.dart';

/// Every user-facing failure message.
///
/// This section is the reason ADR-0004 exists before the `sealed class Failure` of W1 flex: a `Failure` lives in `domain/`, which must not import
/// Flutter (CLAUDE.md 3), so it cannot carry its own message. It carries a type; presentation maps that type to one of these getters.
abstract class GPLocaleBaseError {
  const GPLocaleBaseError();

  String get network;
  String get timeout;
  String get authentication;
  String get authorization;

  /// One getter per `GPValidationCode`. Deliberately not one generic `validation` string: "Please check the information you entered" makes the user hunt
  /// for the field that is wrong, and the whole reason `GPValidationCode` exists is to say which one it is.
  ///
  /// **No limit numbers in the copy.** `accountNameTooLong` does not read "max 100 characters": the limit lives in `Account.nameMaxLength`, presentation
  /// must not import a feature's domain to build a sentence, and duplicating `100` in two languages is a number that goes stale silently. The form field
  /// shows the limit with a live counter instead, which tells the user *before* they hit it rather than after.
  String get validationAccountNameEmpty;
  String get validationAccountNameTooLong;
  String get conflict;
  String get database;
  String get unknown;
  String get routeNotFoundTitle;
  String get routeNotFoundMessage;
}
