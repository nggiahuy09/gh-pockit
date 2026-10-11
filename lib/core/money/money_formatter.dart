import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/currency_code.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

/// Never hands `intl` a `double`: the integer part is formatted as an `int` and the fraction joined as digits (golden rule 2).
@immutable
final class GPMoneyFormatter {
  const GPMoneyFormatter(this.locale);

  /// Language-only, so `en` gets the en-US patterns `intl` ships as its default.
  final GPLocale locale;

  /// ISO-4217 exponents run 0–4. A table because `math.pow` returns a `double`.
  static const List<int> _powersOfTen = <int>[1, 10, 100, 1000, 10000];

  /// Static caches: building a `NumberFormat` reads locale data, and this class is constructed inside `build()`.
  static final Map<String, NumberFormat> _numberFormats = <String, NumberFormat>{};
  static final Map<String, _CurrencyAffixes> _affixes = <String, _CurrencyAffixes>{};

  /// Never throws: an unknown currency still prints (see [_exponentOf]). With `withSymbol: false` the result is exactly what [parse] reads back.
  String format(Money money, {bool withSymbol = true}) {
    final currency = CurrencyCode.fromCode(money.currencyCode);
    final exponent = _exponentOf(currency);
    final divisor = _powersOfTen[exponent];

    // The remainder is smaller than the divisor, so its `abs()` is safe even for the 64-bit floor.
    final integerPart = money.minorUnits ~/ divisor;
    final fractionPart = money.minorUnits.remainder(divisor).abs();

    final numbers = _numberFormatFor(locale);
    final minusSign = numbers.symbols.MINUS_SIGN;

    // Formatted signed, since the floor's `abs()` is still negative; the sign then moves ahead of the symbol (`-$12.34`, never `$-12.34`).
    var digits = numbers.format(integerPart);
    var sign = '';
    if (digits.startsWith(minusSign)) {
      sign = minusSign;
      digits = digits.substring(minusSign.length);
    } else if (money.isNegative) {
      // -5 cents: the integer part is 0 and carries no sign.
      sign = minusSign;
    }

    if (exponent > 0) digits = '$digits${numbers.symbols.DECIMAL_SEP}${fractionPart.toString().padLeft(exponent, '0')}';

    if (!withSymbol) return '$sign$digits';

    final affixes = _affixesFor(locale, currency?.symbol ?? money.currencyCode);
    return '$sign${affixes.prefix}$digits${affixes.suffix}';
  }

  /// Null when [text] is not an amount, including more fractional digits than the currency has. Throws [ArgumentError] on a malformed [currencyCode].
  /// Grouping separators are stripped, not validated: `1.500.00` is a half-typed `1.500.000`.
  Money? parse(String text, {required String currencyCode}) {
    // Validates the code up front: checked only once the text parses, the same bug would throw or not depending on what was typed.
    Money.zero(currencyCode);

    final currency = CurrencyCode.fromCode(currencyCode);
    final exponent = _exponentOf(currency);
    final numbers = _numberFormatFor(locale);

    var cleaned = text.trim();
    if (currency != null) cleaned = cleaned.replaceAll(currency.symbol, '');

    cleaned = cleaned
        .replaceAll(currencyCode, '')
        .replaceAll(numbers.symbols.GROUP_SEP, '')
        // Includes the non-breaking space `intl` puts before a Vietnamese symbol.
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

  /// Empty matches: `'12'` has no fraction and is still twelve dollars.
  static final RegExp _digitsOnly = RegExp(r'^[0-9]*$');

  /// 0 for an unknown currency (a newer build's row): the stored minor units print unchanged rather than behind a guessed decimal point.
  static int _exponentOf(CurrencyCode? currency) => currency?.exponent ?? 0;

  static NumberFormat _numberFormatFor(GPLocale locale) => _numberFormats.putIfAbsent(locale.languageCode, () => NumberFormat.decimalPattern(locale.languageCode));

  /// Formats a zero and reads what sits either side of it (`₫0` in English, `0 ₫` in Vietnamese). A symbol has no digit, so the zero is the amount.
  static _CurrencyAffixes _affixesFor(GPLocale locale, String symbol) {
    return _affixes.putIfAbsent('${locale.languageCode}|$symbol', () {
      final probe = NumberFormat.currency(locale: locale.languageCode, symbol: symbol, decimalDigits: 0);
      final skeleton = probe.format(0);
      final zeroAt = skeleton.indexOf(probe.symbols.ZERO_DIGIT);

      return _CurrencyAffixes(prefix: skeleton.substring(0, zeroAt), suffix: skeleton.substring(zeroAt + 1));
    });
  }
}

@immutable
class _CurrencyAffixes {
  const _CurrencyAffixes({required this.prefix, required this.suffix});

  final String prefix;
  final String suffix;
}
