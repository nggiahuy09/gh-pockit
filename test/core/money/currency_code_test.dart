import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/money/currency_code.dart';
import 'package:ghpockit/core/money/money.dart';

/// The membership half of what `Money` deliberately does not check (W3 T4).
void main() {
  group('the catalog', () {
    test('knows the exponent of each currency it ships', () {
      // The one fact the formatter consumes, and the one that is wrong by default: assuming 2 everywhere turns 1.500.000 ₫ into 15.000,00 ₫.
      expect(CurrencyCode.vnd.exponent, 0);
      expect(CurrencyCode.usd.exponent, 2);
    });

    test('every entry carries a code `Money` would accept', () {
      // The two types have to agree on what a currency code looks like, or a catalogued currency becomes one `Money` refuses to construct.
      for (final currency in CurrencyCode.values) {
        expect(() => Money(1, currency.code), returnsNormally, reason: '${currency.code} should construct');
        expect(currency.symbol, isNotEmpty);
      }
    });

    test('exponents stay inside the range the formatter can scale', () {
      // `GPMoneyFormatter` indexes a five-entry table of powers of ten. ISO-4217 never goes past 4, but a typo here would be a RangeError on a screen.
      for (final currency in CurrencyCode.values) {
        expect(currency.exponent, inInclusiveRange(0, 4));
      }
    });
  });

  group('fromCode', () {
    test('resolves a code we ship', () {
      expect(CurrencyCode.fromCode('VND'), CurrencyCode.vnd);
      expect(CurrencyCode.fromCode('USD'), CurrencyCode.usd);
    });

    test('returns null for a well-formed code we do not', () {
      // Not an error: `Money` accepts any three uppercase letters on purpose, so this is the question "can we render it", not "is it valid".
      expect(CurrencyCode.fromCode('XYZ'), isNull);
      expect(CurrencyCode.fromCode('EUR'), isNull);
    });

    test('is case-sensitive, because a lowercase code is corruption by another route', () {
      // `Money` already rejects 'vnd'. Accepting it here would let a corrupt row render as if it were fine.
      expect(CurrencyCode.fromCode('vnd'), isNull);
      expect(CurrencyCode.fromCode('Usd'), isNull);
      expect(CurrencyCode.fromCode(''), isNull);
    });
  });
}
