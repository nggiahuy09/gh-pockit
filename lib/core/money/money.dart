import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Checks a currency code's shape only; whether the app knows the currency is `CurrencyCode`'s job (ADR-0007).
// Fields in `Money(minorUnits, currencyCode)` order, not by type: golden rule 2 names that signature.
@immutable
final class Money with Equatable implements Comparable<Money> {
  /// Throws [ArgumentError] unless [currencyCode] is three A–Z letters: here a bad code is a bug. Untrusted input goes through [Money.fromStorage].
  factory Money(int minorUnits, String currencyCode) {
    if (!_currencyCodePattern.hasMatch(currencyCode)) {
      throw ArgumentError.value(currencyCode, 'currencyCode', 'must be three uppercase letters (ISO-4217), e.g. VND or USD');
    }

    return Money._(minorUnits, currencyCode);
  }

  factory Money.zero(String currencyCode) => Money(0, currencyCode);

  const Money._(this.minorUnits, this.currencyCode);

  /// The non-throwing twin of [Money.new], for untrusted rows (ADR-0007).
  static Money? fromStorage(int minorUnits, String currencyCode) => _currencyCodePattern.hasMatch(currencyCode) ? Money._(minorUnits, currencyCode) : null;

  /// Negative is legal: an overdrawn balance, a difference.
  final int minorUnits;

  final String currencyCode;

  static final _currencyCodePattern = RegExp(r'^[A-Z]{3}$');

  bool get isZero => minorUnits == 0;

  bool get isNegative => minorUnits < 0;

  bool get isPositive => minorUnits > 0;

  @override
  List<Object?> get props => [minorUnits, currencyCode];

  @override
  int compareTo(Money other) => minorUnits.compareTo(_sameCurrency(other));

  /// Throws [MoneyCurrencyMismatchError] across currencies. Overflow wraps unguarded, on purpose (ADR-0007).
  Money operator +(Money other) => Money._(minorUnits + _sameCurrency(other), currencyCode);

  Money operator -(Money other) => Money._(minorUnits - _sameCurrency(other), currencyCode);

  /// The 64-bit floor is its own negation (ADR-0007).
  Money operator -() => Money._(-minorUnits, currencyCode);

  bool operator <(Money other) => compareTo(other) < 0;

  bool operator <=(Money other) => compareTo(other) <= 0;

  bool operator >(Money other) => compareTo(other) > 0;

  bool operator >=(Money other) => compareTo(other) >= 0;

  Money abs() => isNegative ? -this : this;

  /// Returns [other]'s amount once it is known to share this currency.
  int _sameCurrency(Money other) {
    if (other.currencyCode != currencyCode) throw MoneyCurrencyMismatchError(currencyCode: currencyCode, otherCurrencyCode: other.currencyCode);

    return other.minorUnits;
  }

  /// Prints the amount: for test output, never for a log (golden rule 9).
  @override
  String toString() => 'Money($minorUnits, $currencyCode)';
}

/// An `Error`, not an outcome: no UI combines two currencies, so reaching this is a bug (ADR-0006).
final class MoneyCurrencyMismatchError extends Error {
  MoneyCurrencyMismatchError({required this.currencyCode, required this.otherCurrencyCode});

  final String currencyCode;
  final String otherCurrencyCode;

  @override
  String toString() => 'MoneyCurrencyMismatchError: cannot combine $currencyCode with $otherCurrencyCode without an explicit conversion';
}
