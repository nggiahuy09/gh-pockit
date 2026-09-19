import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/money/money.dart';

/// Golden rule 2 under test (W2 T5, pulled forward from W3 T2).
///
/// What is asserted here is not "integers add up" — it is the set of decisions that make this type worth having over a bare `int`: the currency travels
/// with the amount, mixing currencies is loud rather than silent, and zero dong is not zero dollars.
void main() {
  group('construction', () {
    test('keeps minor units exactly, with no scaling of its own', () {
      // VND has exponent 0, so the integer is the whole dong amount; USD has exponent 2, so 1234 is $12.34. Money does not know the difference and must
      // not — applying an exponent here would mean the same call meant two things depending on the currency.
      expect(Money(1500000, 'VND').minorUnits, 1500000);
      expect(Money(1234, 'USD').minorUnits, 1234);
    });

    test('accepts a negative amount', () {
      // An overdrawn balance and a refund are both real. Rejecting negatives here would push every caller into carrying a sign beside the amount.
      expect(Money(-5000, 'VND').isNegative, isTrue);
    });

    test('Money.zero is the additive identity', () {
      final wallet = Money(1500000, 'VND');

      expect(Money.zero('VND').isZero, isTrue);
      expect(wallet + Money.zero('VND'), wallet);
    });

    test('rejects a currency code that is not three uppercase letters', () {
      // Shape only — whether VND exists is the W3 T4 catalog's question. What this guards is that `minorUnits` stays interpretable at all.
      expect(() => Money(1, 'vnd'), throwsArgumentError);
      expect(() => Money(1, 'VN'), throwsArgumentError);
      expect(() => Money(1, 'VNDD'), throwsArgumentError);
      expect(() => Money(1, 'V N'), throwsArgumentError);
      expect(() => Money(1, ''), throwsArgumentError);
      // The anchors in the pattern are what this one is for: an unanchored regex would accept it.
      expect(() => Money(1, 'xxVNDxx'), throwsArgumentError);
    });

    test('accepts an unknown but well-formed code', () {
      // Membership is not this type's job, and hard-coding a list here would mean a new currency needs a change in `core/`.
      expect(Money(1, 'XYZ').currencyCode, 'XYZ');
    });
  });

  group('fromStorage', () {
    test('parses a well-formed pair', () {
      expect(Money.fromStorage(1500000, 'VND'), Money(1500000, 'VND'));
      expect(Money.fromStorage(-4500, 'USD'), Money(-4500, 'USD'));
    });

    test('returns null instead of throwing on a malformed code', () {
      // The boundary twin of the throwing constructor. Inside the program a bad code is a bug; coming back out of SQLite it is data, and `AccountMapper`
      // turns this null into a GPDatabaseFailure rather than catching an `Error`.
      expect(Money.fromStorage(1, 'vnd'), isNull);
      expect(Money.fromStorage(1, 'VN'), isNull);
      expect(Money.fromStorage(1, ''), isNull);
    });

    test('agrees with the constructor on what is valid', () {
      // Two entry points, one rule. If they ever diverge, a row that cannot be constructed becomes a row that can be read, or the reverse.
      const valid = ['VND', 'USD', 'XYZ'];
      const malformed = ['vnd', 'VN', 'VNDD', '', 'V N', 'xxVNDxx'];

      for (final code in valid) {
        expect(Money.fromStorage(1, code), Money(1, code), reason: '$code should parse');
      }

      for (final code in malformed) {
        expect(Money.fromStorage(1, code), isNull, reason: '$code should not parse');
        expect(() => Money(1, code), throwsArgumentError, reason: '$code should not construct');
      }
    });
  });

  group('arithmetic', () {
    test('adds and subtracts within one currency', () {
      expect(Money(1500000, 'VND') + Money(500000, 'VND'), Money(2000000, 'VND'));
      expect(Money(1500000, 'VND') - Money(500000, 'VND'), Money(1000000, 'VND'));
    });

    test('subtraction may go negative rather than clamping', () {
      // Clamping at zero would turn "you are 50k short" into "you have nothing", which is a different and wrong statement.
      expect(Money(1000, 'VND') - Money(3000, 'VND'), Money(-2000, 'VND'));
    });

    test('negation and abs keep the currency', () {
      expect(-Money(1500000, 'VND'), Money(-1500000, 'VND'));
      expect(Money(-1500000, 'VND').abs(), Money(1500000, 'VND'));
      expect(Money(1500000, 'VND').abs(), Money(1500000, 'VND'));
    });

    test('mixing currencies throws instead of converting', () {
      // The blueprint's one hard rule for this type. A conversion needs a rate and a date; picking either silently produces a number that looks right.
      expect(() => Money(1, 'VND') + Money(1, 'USD'), throwsA(isA<MoneyCurrencyMismatchError>()));
      expect(() => Money(1, 'VND') - Money(1, 'USD'), throwsA(isA<MoneyCurrencyMismatchError>()));
      expect(() => Money(1, 'VND').compareTo(Money(1, 'USD')), throwsA(isA<MoneyCurrencyMismatchError>()));
      expect(() => Money(1, 'VND') < Money(1, 'USD'), throwsA(isA<MoneyCurrencyMismatchError>()));
    });

    test('the mismatch error is an Error, not an Exception', () {
      // ADR-0006's dividing line, asserted rather than assumed: no UI offers "add dong to dollars", so this is a bug and must not be caught and shown to
      // a user. `Error` is how Dart says that.
      expect(MoneyCurrencyMismatchError('VND', 'USD'), isA<Error>());
      expect(MoneyCurrencyMismatchError('VND', 'USD'), isNot(isA<Exception>()));
    });

    test('the mismatch error names both currencies and no amounts', () {
      // Golden rule 9: this one is printable, so it must stay free of financial payloads.
      final error = MoneyCurrencyMismatchError('VND', 'USD').toString();

      expect(error, contains('VND'));
      expect(error, contains('USD'));
      expect(error, isNot(contains('1500000')));
    });
  });

  group('comparison', () {
    test('orders by amount', () {
      expect(Money(1000, 'VND') < Money(2000, 'VND'), isTrue);
      expect(Money(2000, 'VND') > Money(1000, 'VND'), isTrue);
      expect(Money(1000, 'VND') <= Money(1000, 'VND'), isTrue);
      expect(Money(1000, 'VND') >= Money(1000, 'VND'), isTrue);
      expect(Money(-1, 'VND') < Money.zero('VND'), isTrue);
    });

    test('sorts a list through Comparable', () {
      final amounts = [Money(300, 'VND'), Money(-100, 'VND'), Money(200, 'VND')]..sort();

      expect(amounts, [Money(-100, 'VND'), Money(200, 'VND'), Money(300, 'VND')]);
    });
  });

  group('equality', () {
    test('is by value, not identity', () {
      expect(Money(1500000, 'VND'), Money(1500000, 'VND'));
      expect(Money(1500000, 'VND').hashCode, Money(1500000, 'VND').hashCode);
    });

    test('the same number in two currencies is not the same money', () {
      // The test that stops a mixed-currency bug from passing: if these compared equal, a VND amount rendered as USD would look correct here.
      expect(Money.zero('VND'), isNot(Money.zero('USD')));
      expect(Money(1000, 'VND'), isNot(Money(1000, 'USD')));
    });
  });

  test('toString carries the amount, for test output only', () {
    // Documented hazard rather than an oversight: `AccountEntity.toString` omits its balance and `redactSensitiveFields` blanks `amount`/`balance`/`minorunits`
    // keys, so an amount only reaches a log if somebody interpolates this by hand. The alternative — a redacted `Money(VND)` — makes every failing
    // expectation in this file unreadable.
    expect(Money(1500000, 'VND').toString(), 'Money(1500000, VND)');
  });
}
