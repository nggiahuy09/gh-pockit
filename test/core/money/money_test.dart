import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/money/money.dart';

void main() {
  group('construction', () {
    test('keeps minor units exactly, with no scaling of its own', () {
      // Money never applies the exponent: 1234 is 1234 dong but $12.34.
      expect(Money(1500000, 'VND').minorUnits, 1500000);
      expect(Money(1234, 'USD').minorUnits, 1234);
    });

    test('accepts a negative amount', () {
      // Overdrawn balances and refunds are real.
      expect(Money(-5000, 'VND').isNegative, isTrue);
    });

    test('Money.zero is the additive identity', () {
      final wallet = Money(1500000, 'VND');

      expect(Money.zero('VND').isZero, isTrue);
      expect(wallet + Money.zero('VND'), wallet);
    });

    test('rejects a currency code that is not three uppercase letters', () {
      // Shape only; whether the currency exists is the catalog's question.
      expect(() => Money(1, 'vnd'), throwsArgumentError);
      expect(() => Money(1, 'VN'), throwsArgumentError);
      expect(() => Money(1, 'VNDD'), throwsArgumentError);
      expect(() => Money(1, 'V N'), throwsArgumentError);
      expect(() => Money(1, ''), throwsArgumentError);
      // The anchors in the pattern are what this one is for: an unanchored regex would accept it.
      expect(() => Money(1, 'xxVNDxx'), throwsArgumentError);
    });

    test('accepts an unknown but well-formed code', () {
      expect(Money(1, 'XYZ').currencyCode, 'XYZ');
    });
  });

  group('fromStorage', () {
    test('parses a well-formed pair', () {
      expect(Money.fromStorage(1500000, 'VND'), Money(1500000, 'VND'));
      expect(Money.fromStorage(-4500, 'USD'), Money(-4500, 'USD'));
    });

    test('returns null instead of throwing on a malformed code', () {
      // A malformed code read from SQLite is data, not a bug (ADR-0006): null, never a throw.
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
      expect(Money(1000, 'VND') - Money(3000, 'VND'), Money(-2000, 'VND'));
    });

    test('negation and abs keep the currency', () {
      expect(-Money(1500000, 'VND'), Money(-1500000, 'VND'));
      expect(Money(-1500000, 'VND').abs(), Money(1500000, 'VND'));
      expect(Money(1500000, 'VND').abs(), Money(1500000, 'VND'));
    });

    test('mixing currencies throws instead of converting', () {
      expect(() => Money(1, 'VND') + Money(1, 'USD'), throwsA(isA<MoneyCurrencyMismatchError>()));
      expect(() => Money(1, 'VND') - Money(1, 'USD'), throwsA(isA<MoneyCurrencyMismatchError>()));
      expect(() => Money(1, 'VND').compareTo(Money(1, 'USD')), throwsA(isA<MoneyCurrencyMismatchError>()));
      expect(() => Money(1, 'VND') < Money(1, 'USD'), throwsA(isA<MoneyCurrencyMismatchError>()));
    });

    test('the mismatch error is an Error, not an Exception', () {
      expect(MoneyCurrencyMismatchError('VND', 'USD'), isA<Error>());
      expect(MoneyCurrencyMismatchError('VND', 'USD'), isNot(isA<Exception>()));
    });

    test('the mismatch error names both currencies and no amounts', () {
      // Golden rule 9: printable, so no amounts.
      final error = MoneyCurrencyMismatchError('VND', 'USD').toString();

      expect(error, contains('VND'));
      expect(error, contains('USD'));
      expect(error, isNot(contains('1500000')));
    });
  });

  group('magnitude', () {
    const ceiling = 9223372036854775807;
    const floor = -9223372036854775808;

    test('counts exactly at magnitudes where a double has stopped counting', () {
      // 2^53 + 1 is the first integer a double cannot represent; a lifetime `SUM()` in VND can reach it.
      // `avoid_js_rounded_ints`: being unrepresentable in a double is the point, and there is no JS target.
      // ignore: avoid_js_rounded_ints
      const beyondDoublePrecision = 9007199254740993;

      expect(beyondDoublePrecision.toDouble().toInt(), 9007199254740992, reason: 'a double loses this unit');
      expect(Money(beyondDoublePrecision, 'VND').minorUnits, beyondDoublePrecision);
      expect(Money(beyondDoublePrecision, 'VND') + Money(1, 'VND'), Money(9007199254740994, 'VND'));
      expect(Money(beyondDoublePrecision, 'VND') - Money(1, 'VND'), Money(9007199254740992, 'VND'));
    });

    test('carries an amount at either end of the 64-bit range', () {
      expect(Money(ceiling, 'VND').minorUnits, ceiling);
      expect(Money(floor, 'VND').minorUnits, floor);
      // Written out, not `ceiling - 1`, so the expectation is not computed by the operation under test. Same JS caveat.
      // ignore: avoid_js_rounded_ints
      expect(Money(ceiling, 'VND') - Money(1, 'VND'), Money(9223372036854775806, 'VND'));
      expect(Money(floor, 'VND') + Money(1, 'VND'), Money(-9223372036854775807, 'VND'));
    });

    test('fromStorage round-trips the whole range a SQLite INTEGER can hold', () {
      // Same 64 bits as the column: anything the database returns must be readable.
      expect(Money.fromStorage(ceiling, 'VND'), Money(ceiling, 'VND'));
      expect(Money.fromStorage(floor, 'VND'), Money(floor, 'VND'));
    });

    test('addition past the ceiling wraps instead of throwing — the documented bound, not a bug', () {
      // Deliberately unguarded (ROADMAP W3 T3, option A): a throw here would reverse that decision, not fix a bug.
      expect(Money(ceiling, 'VND') + Money(1, 'VND'), Money(floor, 'VND'));
      expect(Money(floor, 'VND') - Money(1, 'VND'), Money(ceiling, 'VND'));
    });

    test('the floor is its own negation, so abs() of it stays negative', () {
      // Two's complement: `floor` has no positive twin, so `abs()` is not a magnitude at exactly this value.
      expect(-Money(floor, 'VND'), Money(floor, 'VND'));
      expect(Money(floor, 'VND').abs().isNegative, isTrue);
      expect(Money(ceiling, 'VND').abs(), Money(ceiling, 'VND'));
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
      expect(Money.zero('VND'), isNot(Money.zero('USD')));
      expect(Money(1000, 'VND'), isNot(Money(1000, 'USD')));
    });
  });

  test('toString carries the amount, for test output only', () {
    // Prints the amount on purpose: entities leave it out of their own `toString`, and the log redactor blanks amount keys.
    expect(Money(1500000, 'VND').toString(), 'Money(1500000, VND)');
  });
}
