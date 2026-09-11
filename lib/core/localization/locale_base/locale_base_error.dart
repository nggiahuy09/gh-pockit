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
  String get validation;
  String get conflict;
  String get database;
  String get unknown;
  String get routeNotFoundTitle;
  String get routeNotFoundMessage;
}
