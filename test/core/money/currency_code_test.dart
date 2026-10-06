import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/money/currency_code.dart';
import 'package:ghpockit/core/money/money.dart';

void main() {
  group('the catalog', () {
    test('knows the exponent of each currency it ships', () {
      // Assuming 2 everywhere would turn 1.500.000 ₫ into 15.000,00 ₫.
      expect(CurrencyCode.vnd.exponent, 0);
      expect(CurrencyCode.usd.exponent, 2);
    });

    test('every entry carries a code `Money` would accept', () {
      for (final currency in CurrencyCode.values) {
        expect(() => Money(1, currency.code), returnsNormally, reason: '${currency.code} should construct');
        expect(currency.symbol, isNotEmpty);
      }
    });

    test('exponents stay inside the range the formatter can scale', () {
      // `GPMoneyFormatter` indexes a five-entry table of powers of ten.
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
      // `Money` accepts any three uppercase letters: this answers "can we render it", not "is it valid".
      expect(CurrencyCode.fromCode('XYZ'), isNull);
      expect(CurrencyCode.fromCode('EUR'), isNull);
    });

    test('is case-sensitive, because a lowercase code is corruption by another route', () {
      expect(CurrencyCode.fromCode('vnd'), isNull);
      expect(CurrencyCode.fromCode('Usd'), isNull);
      expect(CurrencyCode.fromCode(''), isNull);
    });
  });
}
