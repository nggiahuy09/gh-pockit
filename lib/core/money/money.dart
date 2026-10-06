import 'package:meta/meta.dart';

/// Checks a currency code's shape only; whether the app knows the currency is `CurrencyCode`'s job (ADR-0007).
@immutable
final class Money implements Comparable<Money> {
  /// Throws [ArgumentError] unless [currencyCode] is three A–Z letters: here a bad code is a bug. Untrusted input goes through [Money.fromStorage].
  factory Money(int minorUnits, String currencyCode) {
    if (!_currencyCodePattern.hasMatch(currencyCode)) {
      throw ArgumentError.value(currencyCode, 'currencyCode', 'must be three uppercase letters (ISO-4217), e.g. VND or USD');
    }

    return Money._(minorUnits, currencyCode);
  }

  factory Money.zero(String currencyCode) => Money(0, currencyCode);

  const Money._(this.minorUnits, this.currencyCode);

  /// The non-throwing twin of [Money.new], for untrusted rows. Revisit the name when the first DTO calls it (ADR-0007).
  static Money? fromStorage(int minorUnits, String currencyCode) {
    if (!_currencyCodePattern.hasMatch(currencyCode)) return null;

    return Money._(minorUnits, currencyCode);
  }

  static final RegExp _currencyCodePattern = RegExp(r'^[A-Z]{3}$');

  /// Negative is legal: an overdrawn balance, a difference.
  final int minorUnits;

  final String currencyCode;

  bool get isZero => minorUnits == 0;

  bool get isNegative => minorUnits < 0;

  bool get isPositive => minorUnits > 0;

  /// Throws [MoneyCurrencyMismatchError] across currencies. Overflow wraps unguarded, on purpose (ADR-0007).
  Money operator +(Money other) => Money._(minorUnits + _sameCurrency(other), currencyCode);

  Money operator -(Money other) => Money._(minorUnits - _sameCurrency(other), currencyCode);

  /// The 64-bit floor is its own negation (ADR-0007).
  Money operator -() => Money._(-minorUnits, currencyCode);

  Money abs() => isNegative ? -this : this;

  @override
  int compareTo(Money other) => minorUnits.compareTo(_sameCurrency(other));

  bool operator <(Money other) => compareTo(other) < 0;

  bool operator <=(Money other) => compareTo(other) <= 0;

  bool operator >(Money other) => compareTo(other) > 0;

  bool operator >=(Money other) => compareTo(other) >= 0;

  /// Returns [other]'s amount once it is known to share this currency.
  int _sameCurrency(Money other) {
    if (other.currencyCode != currencyCode) {
      throw MoneyCurrencyMismatchError(currencyCode, other.currencyCode);
    }

    return other.minorUnits;
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Money && other.minorUnits == minorUnits && other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(minorUnits, currencyCode);

  /// Prints the amount: for test output, never for a log (golden rule 9).
  @override
  String toString() => 'Money($minorUnits, $currencyCode)';
}

/// An `Error`, not an outcome: no UI combines two currencies, so reaching this is a bug (ADR-0006).
final class MoneyCurrencyMismatchError extends Error {
  MoneyCurrencyMismatchError(this.currencyCode, this.otherCurrencyCode);

  final String currencyCode;
  final String otherCurrencyCode;

  @override
  String toString() => 'MoneyCurrencyMismatchError: cannot combine $currencyCode with $otherCurrencyCode without an explicit conversion';
}
