import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/money/money_formatter.dart';

/// W3 T4: the same amount, read correctly in two languages, with no `double` on the way to the screen.
///
/// The non-breaking space matters and is written as `\u00a0` throughout: that is the character `intl` puts between a Vietnamese amount and its symbol, and
/// an expectation with a plain space in it fails in a way that is very hard to see in the diff.
void main() {
  const en = GPMoneyFormatter(GPLocale.en);
  const vi = GPMoneyFormatter(GPLocale.vi);

  group('format', () {
    test('inverts the separators between the two languages', () {
      // The headline of the task. `.` groups in Vietnamese and separates decimals in English, and getting it backwards misstates an amount by a factor of
      // a thousand rather than looking merely foreign.
      expect(en.format(Money(1500000, 'VND')), '₫1,500,000');
      expect(vi.format(Money(1500000, 'VND')), '1.500.000\u00a0₫');
      expect(en.format(Money(123456, 'USD')), r'$1,234.56');
      expect(vi.format(Money(123456, 'USD')), '1.234,56\u00a0\$');
    });

    test('applies the currency exponent, not a default of two', () {
      // 1500000 is one and a half million dong and fifteen thousand dollars. The catalog is what tells them apart.
      expect(vi.format(Money(1500000, 'VND')), '1.500.000\u00a0₫');
      expect(vi.format(Money(1500000, 'USD')), '15.000,00\u00a0\$');
    });

    test('pads a fraction that is shorter than the exponent', () {
      expect(en.format(Money(5, 'USD')), r'$0.05');
      expect(en.format(Money(50, 'USD')), r'$0.50');
      expect(vi.format(Money(5, 'USD')), '0,05\u00a0\$');
    });

    test('puts the sign outside the symbol, in both languages', () {
      // Every locale writes -$12.34 and none writes $-12.34, which is why the sign is lifted out of the number before the symbol is attached.
      expect(en.format(Money(-1234, 'USD')), r'-$12.34');
      expect(vi.format(Money(-1234, 'USD')), '-12,34\u00a0\$');
      expect(en.format(Money(-1500000, 'VND')), '-₫1,500,000');
      expect(vi.format(Money(-1500000, 'VND')), '-1.500.000\u00a0₫');
    });

    test('keeps the sign on an amount smaller than one major unit', () {
      // The integer part is 0, which carries no sign of its own. Dropping it here would print a debt as a credit.
      expect(en.format(Money(-5, 'USD')), r'-$0.05');
      expect(vi.format(Money(-5, 'USD')), '-0,05\u00a0\$');
    });

    test('formats zero without a sign', () {
      expect(en.format(Money.zero('USD')), r'$0.00');
      expect(vi.format(Money.zero('VND')), '0\u00a0₫');
    });

    test('omits the symbol on request, and that output is what parse accepts', () {
      // What a text field shows while being edited. The round trip is asserted in the `parse` group.
      expect(en.format(Money(123456, 'USD'), withSymbol: false), '1,234.56');
      expect(vi.format(Money(1500000, 'VND'), withSymbol: false), '1.500.000');
      expect(vi.format(Money(-5, 'USD'), withSymbol: false), '-0,05');
    });

    test('prints an uncatalogued currency instead of throwing or guessing', () {
      // Reachable without a bug on our side: `Money.fromStorage` checks a code's shape and not its membership, so a row written by a newer build survives
      // a downgrade and arrives here. Exponent 0 shows the stored minor units unchanged — guessing 2 would move the decimal point and restate the amount.
      expect(en.format(Money(1234, 'XYZ')), 'XYZ1,234');
      expect(vi.format(Money(1234, 'XYZ')), '1.234\u00a0XYZ');
      expect(vi.format(Money(1234, 'XYZ'), withSymbol: false), '1.234');
    });
  });

  group('format does not route an amount through a double', () {
    // Golden rule 2 at the last mile. `NumberFormat.currency().format()` takes a `num`, so the obvious implementation computes `minorUnits / 100` — and
    // then the number on screen is not the number in the row. These are the magnitudes where that stops being theoretical.
    test('prints every digit at 2^53 + 1, where a double has already lost one', () {
      // Same standing exception as in `money_test.dart`: `avoid_js_rounded_ints` is right and beside the point, because being unrepresentable in a
      // double is the assertion, and this app has no JS target (CLAUDE.md §1).
      // ignore: avoid_js_rounded_ints
      const beyondDoublePrecision = 9007199254740993; // Asserted unrepresentable in a double in `money_test.dart`.

      expect(vi.format(Money(beyondDoublePrecision, 'VND')), '9.007.199.254.740.993\u00a0₫');
      expect(en.format(Money(beyondDoublePrecision, 'USD')), r'$90,071,992,547,409.93');
    });

    test('prints the ends of the 64-bit range, including the floor that has no positive twin', () {
      // `(-9223372036854775808).abs()` is still negative, so a formatter that takes the magnitude first prints the wrong number or crashes here.
      expect(vi.format(Money(9223372036854775807, 'VND')), '9.223.372.036.854.775.807\u00a0₫');
      expect(vi.format(Money(-9223372036854775808, 'VND')), '-9.223.372.036.854.775.808\u00a0₫');
      expect(en.format(Money(-9223372036854775808, 'USD')), r'-$92,233,720,368,547,758.08');
    });
  });

  group('parse', () {
    test('reads what its own formatter wrote, in both languages', () {
      // The property that matters for an edit form: opening an existing amount and saving it unchanged must not change it.
      final amounts = <Money>[
        Money(1500000, 'VND'),
        Money(-1500000, 'VND'),
        Money(123456, 'USD'),
        Money(-5, 'USD'),
        Money.zero('USD'),
        // The round trip has to hold past double precision too, for the reason given above.
        // ignore: avoid_js_rounded_ints
        Money(9007199254740993, 'VND'),
      ];

      for (final formatter in <GPMoneyFormatter>[en, vi]) {
        for (final amount in amounts) {
          expect(
            formatter.parse(formatter.format(amount, withSymbol: false), currencyCode: amount.currencyCode),
            amount,
            reason: '${formatter.locale.languageCode} should read back ${formatter.format(amount)}',
          );
        }
      }
    });

    test('reads the same text as different amounts in different languages', () {
      // `1.234` is one thousand two hundred thirty-four dong in Vietnamese. In English it is one dong and a fraction VND does not have — so it is refused
      // rather than rounded. This pair is the whole reason parsing is locale-aware instead of a `int.parse` on the digits.
      expect(vi.parse('1.234', currencyCode: 'VND'), Money(1234, 'VND'));
      expect(en.parse('1.234', currencyCode: 'VND'), isNull);
      expect(en.parse('1,234', currencyCode: 'VND'), Money(1234, 'VND'));
      expect(vi.parse('1.234,56', currencyCode: 'USD'), Money(123456, 'USD'));
      expect(en.parse('1,234.56', currencyCode: 'USD'), Money(123456, 'USD'));
    });

    test('accepts the symbol, the code and the spacing a user may paste back in', () {
      expect(vi.parse('1.500.000\u00a0₫', currencyCode: 'VND'), Money(1500000, 'VND'));
      expect(en.parse(r'$12.34', currencyCode: 'USD'), Money(1234, 'USD'));
      expect(en.parse('  12.34 USD ', currencyCode: 'USD'), Money(1234, 'USD'));
      expect(vi.parse('-1.500.000 ₫', currencyCode: 'VND'), Money(-1500000, 'VND'));
    });

    test('pads a short fraction and accepts none at all', () {
      expect(en.parse('12.5', currencyCode: 'USD'), Money(1250, 'USD'));
      expect(en.parse('12', currencyCode: 'USD'), Money(1200, 'USD'));
      expect(en.parse('.5', currencyCode: 'USD'), Money(50, 'USD'));
    });

    test('refuses more fractional digits than the currency has', () {
      // Dropping the extra digits would book an amount the user did not type. VND has no subunit at all, so any decimal part is a refusal.
      expect(en.parse('12.345', currencyCode: 'USD'), isNull);
      expect(vi.parse('1234,5', currencyCode: 'VND'), isNull);
    });

    test('strips grouping without validating it', () {
      // Deliberate: `1.500.00` is half-typed `1.500.000`, and a field that rejects it mid-keystroke fights the user. The decimal separator is still
      // exactly one.
      expect(vi.parse('1.500.00', currencyCode: 'VND'), Money(150000, 'VND'));
      expect(vi.parse('1.2.3', currencyCode: 'VND'), Money(123, 'VND'));
      expect(vi.parse('1,2,3', currencyCode: 'VND'), isNull);
    });

    test('returns null for text that is not an amount', () {
      for (final text in <String>['', '   ', 'abc', '-', '₫', '12a', '1e5']) {
        expect(en.parse(text, currencyCode: 'USD'), isNull, reason: '"$text" is not an amount');
        expect(vi.parse(text, currencyCode: 'VND'), isNull, reason: '"$text" is not an amount');
      }
    });

    test('returns null rather than wrapping when the amount will not fit in 64 bits', () {
      // The other side of the bound recorded in `money_test.dart`: the type wraps on overflow, so the parser must not hand it a number that overflows.
      expect(vi.parse('99.999.999.999.999.999.999', currencyCode: 'VND'), isNull);
      expect(en.parse('9,223,372,036,854,775,808', currencyCode: 'VND'), isNull);
      expect(en.parse('9,223,372,036,854,775,807', currencyCode: 'VND'), Money(9223372036854775807, 'VND'));
    });

    test('throws on a malformed currency code, because that one is a bug', () {
      // ADR-0006's line. The amount is user input and comes back null; the code comes from a picker or the row being edited, so 'vnd' here means the
      // program is wrong, not the user.
      expect(() => en.parse('12.34', currencyCode: 'vnd'), throwsArgumentError);
      // Including when the amount itself is unreadable: the check is eager, so the bug does not hide behind whatever the user happened to type.
      expect(() => en.parse('abc', currencyCode: 'vnd'), throwsArgumentError);
      expect(() => en.parse('12', currencyCode: 'VN'), throwsArgumentError);
    });

    test('reads an uncatalogued currency as whole minor units', () {
      // Consistent with how `format` prints it: no exponent is assumed, so what is typed is what is stored.
      expect(vi.parse('1.234', currencyCode: 'XYZ'), Money(1234, 'XYZ'));
      expect(vi.parse('1.234,5', currencyCode: 'XYZ'), isNull);
    });
  });
}
