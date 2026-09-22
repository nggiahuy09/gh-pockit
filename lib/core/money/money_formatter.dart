import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/currency_code.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

/// Renders a [Money] for one language, and reads one back out of what a user typed.
///
/// **The whole job is that `1234` is `$12.34` in English and `12,34 $` in Vietnamese, and `1500000` is `₫1,500,000` and `1.500.000 ₫`.** Grouping
/// separator, decimal separator and symbol placement all move with the locale, and all three are `intl`'s answer here, not ours — that is what promoting
/// `intl` from a transitive dependency to a direct one bought (ADR note in `pubspec.yaml`).
///
/// **No `double` touches an amount on the way to the screen.** This is golden rule 2 at the last mile, and it is the reason this class is more than a call
/// to `NumberFormat.currency().format()`: that method takes a `num`, so using it as intended means computing `minorUnits / 100` and handing a `double` to
/// the formatter. At $12.34 nobody notices; at 2^53 minor units the printed number is simply not the stored one. So the amount is split into an integer
/// part and a fraction with `~/` and `remainder`, and only the integer part — always an exact `int` — is given to `intl`. The fraction is digits, joined
/// with the locale's decimal separator.
///
/// **Bound to a language, `const`, and cheap to construct.** `const GPMoneyFormatter(GPLocale.vi)` is canonicalised by the compiler, and the `NumberFormat`
/// objects — the expensive part, since building one reads locale data — are memoised statically and shared. So a list row may build one per frame without
/// anybody thinking about it. It holds no mutable state and needs no fake, which is why it is a plain type rather than a registered `get_it` singleton like
/// `GPClock`: there is nothing to substitute in a test that `GPMoneyFormatter(GPLocale.en)` does not already give you.
///
/// **`GP`-prefixed, unlike `Money` and `CurrencyCode` beside it** (§3). Those two are domain values every feature's `domain/` imports; this is
/// presentation infrastructure that needs a locale and a formatting library, and `domain/` never touches it. §3's own table makes the same split one row
/// apart: `GPMoneyText` carries the prefix, `Money` does not.
@immutable
final class GPMoneyFormatter {
  const GPMoneyFormatter(this.locale);

  /// The language whose separators and symbol placement this formatter speaks. Region is not a parameter: `GPLocale` is language-only by design
  /// (see `locale.dart`), so `en` means the en-US patterns `intl` ships as that language's default.
  final GPLocale locale;

  /// ISO-4217 exponents run 0–4 (VND 0, USD 2, KWD 3, CLF 4). A lookup table rather than `math.pow`, which returns a `double` — the one type that must not
  /// come near an amount.
  static const List<int> _powersOfTen = <int>[1, 10, 100, 1000, 10000];

  /// Built lazily and shared: constructing a `NumberFormat` reads locale data, and this class is meant to be constructed inside `build()`.
  static final Map<String, NumberFormat> _numberFormats = <String, NumberFormat>{};
  static final Map<String, _CurrencyAffixes> _affixes = <String, _CurrencyAffixes>{};

  /// Formats [money] in this locale, e.g. `1.500.000 ₫` in Vietnamese and `₫1,500,000` in English.
  ///
  /// Pass `withSymbol: false` for a text field: what comes back is exactly what [parse] accepts, which is what makes editing an existing amount a
  /// round trip rather than a reformat.
  ///
  /// Never throws. An amount whose currency is not in the [CurrencyCode] catalog is still printed — see [_exponentOf] for what it degrades to — because
  /// this runs inside `build()`, where the alternative to an odd-looking number is a red screen.
  String format(Money money, {bool withSymbol = true}) {
    final currency = CurrencyCode.fromCode(money.currencyCode);
    final exponent = _exponentOf(currency);
    final divisor = _powersOfTen[exponent];

    // `~/` and `remainder` keep this exact at every magnitude an `int` can hold, including the floor: -9223372036854775808 ~/ 100 is representable even
    // though its absolute value is not, and the remainder is always smaller than the divisor.
    final integerPart = money.minorUnits ~/ divisor;
    final fractionPart = money.minorUnits.remainder(divisor).abs();

    final numbers = _numberFormatFor(locale);
    final minusSign = numbers.symbols.MINUS_SIGN;

    // The integer part goes through `intl` signed rather than as a magnitude, because `(-9223372036854775808).abs()` is still negative — two's complement
    // has one more negative than positive. The sign is then lifted out front, since every locale writes `-$12.34` and none writes `$-12.34`.
    var digits = numbers.format(integerPart);
    var sign = '';
    if (digits.startsWith(minusSign)) {
      sign = minusSign;
      digits = digits.substring(minusSign.length);
    } else if (money.isNegative) {
      // -5 cents: the integer part is 0, which carries no sign of its own, and dropping it here would print a debt as a credit.
      sign = minusSign;
    }

    if (exponent > 0) digits = '$digits${numbers.symbols.DECIMAL_SEP}${fractionPart.toString().padLeft(exponent, '0')}';

    if (!withSymbol) return '$sign$digits';

    final affixes = _affixesFor(locale, currency?.symbol ?? money.currencyCode);
    return '$sign${affixes.prefix}$digits${affixes.suffix}';
  }

  /// Reads an amount a user typed in this locale, returning null when it is not a number.
  ///
  /// [currencyCode] says how to read the text, and it comes from the app — a picker, or the account being edited — never from the same text field. So a
  /// malformed code here is a bug and `Money`'s constructor throws on it, exactly as ADR-0006 asks; a malformed *amount* is an ordinary user outcome and
  /// comes back as null for presentation to turn into a validation message.
  ///
  /// What is accepted is what the locale writes plus what a person actually types: the currency symbol, spaces, and grouping separators are stripped, and
  /// a lone `-` prefix is a sign. Grouping is **stripped, not validated** — `1.500.00` is half-typed `1.500.000`, and a field that rejects it mid-keystroke
  /// is a field that fights the user.
  ///
  /// What is rejected: anything left over that is not a digit, two decimal separators, and more fractional digits than the currency has — `1.234,56` is a
  /// real amount in USD and a nonsense one in VND, and silently dropping the `,56` would book an amount the user did not type. An amount too large for an
  /// `int` is rejected the same way, by [int.tryParse] returning null.
  Money? parse(String text, {required String currencyCode}) {
    // Checked before the text is even looked at, and with `Money`'s own constructor rather than a second copy of its rule. Validating it further down, on
    // the path where the amount happens to parse, would make the same bug throw for `'12'` and return null for `'12.34'` — a bug that comes and goes with
    // what is in the field is one nobody reproduces.
    Money.zero(currencyCode);

    final currency = CurrencyCode.fromCode(currencyCode);
    final exponent = _exponentOf(currency);
    final numbers = _numberFormatFor(locale);

    var cleaned = text.trim();
    if (currency != null) cleaned = cleaned.replaceAll(currency.symbol, '');

    cleaned = cleaned
        .replaceAll(currencyCode, '')
        .replaceAll(numbers.symbols.GROUP_SEP, '')
        // Whitespace in every form the formatter or a keyboard can produce, including the non-breaking space `intl` puts before a Vietnamese symbol.
        .replaceAll(RegExp(r'\s|\u00a0'), '');

    var negative = false;
    if (cleaned.startsWith(numbers.symbols.MINUS_SIGN)) {
      negative = true;
      cleaned = cleaned.substring(numbers.symbols.MINUS_SIGN.length);
    }

    final parts = cleaned.split(numbers.symbols.DECIMAL_SEP);
    if (parts.length > 2) return null;

    final integerDigits = parts.first;
    final fractionDigits = parts.length == 2 ? parts[1] : '';
    if (integerDigits.isEmpty && fractionDigits.isEmpty) return null;
    if (!_digitsOnly.hasMatch(integerDigits) || !_digitsOnly.hasMatch(fractionDigits)) return null;
    if (fractionDigits.length > exponent) return null;

    final minorUnits = int.tryParse('${negative ? '-' : ''}$integerDigits${fractionDigits.padRight(exponent, '0')}');
    if (minorUnits == null) return null;

    return Money(minorUnits, currencyCode);
  }

  /// Empty is allowed: `'12'` in a USD field has no fractional part and means twelve dollars, not a parse error.
  static final RegExp _digitsOnly = RegExp(r'^[0-9]*$');

  /// An unknown currency is printed with exponent 0 and its bare code — `1.234 XYZ` — rather than guessed at.
  ///
  /// Guessing 2 would move the decimal point and restate the amount; exponent 0 prints the stored minor units unchanged, so what is on screen is exactly
  /// what is in the row, and the code beside it says we do not know how to read it. The case is reachable without a bug on our side: `Money.fromStorage`
  /// checks a code's shape and not its membership, so a row written by a newer build survives a downgrade and arrives here intact.
  static int _exponentOf(CurrencyCode? currency) => currency?.exponent ?? 0;

  static NumberFormat _numberFormatFor(GPLocale locale) => _numberFormats.putIfAbsent(locale.languageCode, () => NumberFormat.decimalPattern(locale.languageCode));

  /// Asks `intl` where the symbol goes by formatting a zero and looking at what sits either side of it: `₫0` in English, `0 ₫` in Vietnamese.
  ///
  /// Reading the answer out of a probe rather than hard-coding "before in English, after in Vietnamese" keeps one source of truth for placement, including
  /// the non-breaking space Vietnamese uses — and a currency code is three letters with no digit in it, so the zero is always the amount.
  static _CurrencyAffixes _affixesFor(GPLocale locale, String symbol) {
    return _affixes.putIfAbsent('${locale.languageCode}|$symbol', () {
      final probe = NumberFormat.currency(locale: locale.languageCode, symbol: symbol, decimalDigits: 0);
      final skeleton = probe.format(0);
      final zeroAt = skeleton.indexOf(probe.symbols.ZERO_DIGIT);

      return _CurrencyAffixes(prefix: skeleton.substring(0, zeroAt), suffix: skeleton.substring(zeroAt + 1));
    });
  }
}

/// What `intl` puts before and after the digits for one (locale, symbol) pair.
@immutable
class _CurrencyAffixes {
  const _CurrencyAffixes({required this.prefix, required this.suffix});

  final String prefix;
  final String suffix;
}
