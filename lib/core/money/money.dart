import 'package:meta/meta.dart';

/// An amount of money: an integer count of [minorUnits] plus the [currencyCode] that says how to read it.
///
/// Golden rule 2, and the reason it is a rule: `0.1 + 0.2 == 0.30000000000000004` in every IEEE-754 double, so a ledger built on `double` is a ledger that
/// disagrees with itself after enough additions. An `int` count of the smallest indivisible unit has no such failure mode — `1500000` dong is exactly
/// 1.500.000 ₫ forever, and `1234` cents is exactly $12.34.
///
/// **Pulled forward from W3 T2 into W2 T5**, because `AccountEntity.initialBalance` is the first field in the app that holds money and giving it a bare `int`
/// would mean shipping an entity whose amount travels without its currency — then finding every call site again in a week. What stayed in W3 is
/// `MoneyFormatter` and the `CurrencyCode` catalog: formatting needs `intl`, a locale, and per-currency exponents, and none of that is needed to *hold* an
/// amount correctly.
///
/// **What this class validates and what it does not.** It checks the *shape* of a currency code — three A–Z letters — because that is what makes
/// [minorUnits] interpretable at all. It does not check *membership*: whether `XYZ` is a real ISO-4217 code, and what its exponent is, is the catalog's job
/// at W3 T4. The split is the same one `accounts_table.dart` already makes between its `CHECK (length = 3)` and the business meaning layered on top.
///
/// **Unprefixed, in `core/`.** §3 puts `GP` on everything under `core/` — and names `Money` in the *unprefixed* column two cells later, because it is a
/// domain value object. Both halves of that rule cannot apply at once and the second one wins: this is a value object every feature's `domain/` imports, so
/// it cannot live under one feature, and calling it `GPMoney` would say it is infrastructure when it is the most domain-ish type in the app. The precedent
/// is `core/error/failure.dart`, which `domain/` already imports for the same reason.
@immutable
final class Money implements Comparable<Money> {
  /// Builds an amount, throwing [ArgumentError] if [currencyCode] is not three A–Z letters.
  ///
  /// Throws rather than returns a `GPResult` because a malformed code is never something a user typed: currencies come from a picker, and the only other
  /// source is a row read back out of the local DB. So reaching here with `'vnd '` means either a bug or a corrupt row — ADR-0006's "could a correct program
  /// with a correct user produce this? no → throw". `AccountMapper` at T6 is the one place that catches it, and it converts it to a `GPDatabaseFailure`,
  /// which is exactly what a corrupt row is.
  factory Money(int minorUnits, String currencyCode) {
    if (!_currencyCodePattern.hasMatch(currencyCode)) {
      throw ArgumentError.value(currencyCode, 'currencyCode', 'must be three uppercase letters (ISO-4217), e.g. VND or USD');
    }

    return Money._(minorUnits, currencyCode);
  }

  /// Nothing, in [currencyCode]. The identity element for [operator +], and the sensible opening balance for a new account.
  factory Money.zero(String currencyCode) => Money(0, currencyCode);

  const Money._(this.minorUnits, this.currencyCode);

  /// Parses a stored amount, returning null when [currencyCode] is malformed.
  ///
  /// The boundary twin of the throwing [Money.new], and the split is the same one `AccountType.fromStorage` makes. Inside the program a bad currency code
  /// is a bug and should crash; coming back out of SQLite it is *data*, and the `accounts` row that holds it may have been written by a newer build or
  /// corrupted outright. `AccountMapper` calls this and turns the null into a `GPDatabaseFailure`.
  ///
  /// Null rather than a `GPResult`, so `core/money/` keeps no dependency on `core/error/` — there is exactly one thing that can be wrong here, and the
  /// caller already has to decide what it means in its own layer.
  static Money? fromStorage(int minorUnits, String currencyCode) {
    if (!_currencyCodePattern.hasMatch(currencyCode)) return null;

    return Money._(minorUnits, currencyCode);
  }

  /// Deliberately anchored and case-sensitive: `RegExp('[A-Z]{3}')` without anchors matches `'xxVNDxx'`, and allowing lowercase would let `'vnd'` and `'VND'`
  /// become two currencies that never compare equal.
  static final RegExp _currencyCodePattern = RegExp(r'^[A-Z]{3}$');

  /// The amount, counted in the currency's smallest unit. Negative is legal and meaningful — an overdrawn balance, a refund, the difference between two
  /// amounts in the wrong order.
  final int minorUnits;

  /// ISO-4217, uppercase, e.g. `VND` or `USD`.
  final String currencyCode;

  bool get isZero => minorUnits == 0;

  bool get isNegative => minorUnits < 0;

  bool get isPositive => minorUnits > 0;

  /// Sum. Throws [MoneyCurrencyMismatchError] if the currencies differ — the blueprint's one hard rule for this type.
  ///
  /// There is no implicit conversion and there will not be one: a conversion needs a rate, a rate needs a date, and silently picking either would produce a
  /// number that looks right and is wrong. Multi-currency arithmetic is an explicit feature with an explicit rate, or it is absent.
  Money operator +(Money other) => Money._(minorUnits + _sameCurrency(other), currencyCode);

  /// Difference. Same currency rule as [operator +].
  Money operator -(Money other) => Money._(minorUnits - _sameCurrency(other), currencyCode);

  /// Sign flip, for rendering an expense as the negative of its stored magnitude.
  Money operator -() => Money._(-minorUnits, currencyCode);

  /// Magnitude, currency kept.
  Money abs() => isNegative ? -this : this;

  @override
  int compareTo(Money other) => minorUnits.compareTo(_sameCurrency(other));

  bool operator <(Money other) => compareTo(other) < 0;

  bool operator <=(Money other) => compareTo(other) <= 0;

  bool operator >(Money other) => compareTo(other) > 0;

  bool operator >=(Money other) => compareTo(other) >= 0;

  /// Returns [other]'s amount, having established it is in the same currency. One guard, used by every operation that combines two amounts, so a new
  /// operation cannot forget it.
  int _sameCurrency(Money other) {
    if (other.currencyCode != currencyCode) {
      throw MoneyCurrencyMismatchError(currencyCode, other.currencyCode);
    }

    return other.minorUnits;
  }

  /// Value equality. `Money(0, 'VND') != Money(0, 'USD')`: zero dong and zero dollars are the same number and not the same thing, and treating them as equal
  /// would make a mixed-currency bug pass its own test.
  @override
  bool operator ==(Object other) => identical(this, other) || other is Money && other.minorUnits == minorUnits && other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(minorUnits, currencyCode);

  /// **For test output, never for a log.** This is the one financial payload in the codebase that prints itself in full, because a failing
  /// `expect(balance, ...)` that says `Instance of 'Money'` is worth nothing. Golden rule 9 is held one level up instead: `redactSensitiveFields` blanks
  /// `amount`, `balance` and `minorunits` keys, and `AccountEntity.toString()` deliberately omits its balance — so an amount only reaches a sink if somebody
  /// interpolates this into a log line by hand.
  @override
  String toString() => 'Money($minorUnits, $currencyCode)';
}

/// Thrown when two [Money] values in different currencies are combined.
///
/// An `Error`, not an `Exception`, and the distinction is the whole point: this is unreachable in a correct program. No UI ever offers "add these dong to
/// those dollars", so catching it and showing the user a message would be dressing up a bug as a user problem. It should crash a debug build and be fixed.
///
/// Carries the two codes and no amounts, so it stays printable under golden rule 9.
final class MoneyCurrencyMismatchError extends Error {
  MoneyCurrencyMismatchError(this.currencyCode, this.otherCurrencyCode);

  final String currencyCode;
  final String otherCurrencyCode;

  @override
  String toString() => 'MoneyCurrencyMismatchError: cannot combine $currencyCode with $otherCurrencyCode without an explicit conversion';
}
