/// What the app can render. `Money` checks only a code's shape, so a well-formed code may still be missing here (ADR-0007).
enum CurrencyCode {
  /// ISO-4217 gives VND no minor unit: `1500000` is 1.5 million dong.
  vnd(code: 'VND', exponent: 0, symbol: '₫'),

  usd(code: 'USD', exponent: 2, symbol: r'$');

  const CurrencyCode({required this.code, required this.exponent, required this.symbol});

  final String code;

  /// ISO-4217 minor-unit exponent: how many trailing digits of `Money.minorUnits` are fractional.
  final int exponent;

  /// Placement comes from the locale via `intl`, not from the currency.
  final String symbol;

  /// Case-sensitive on purpose: `Money` rejects lowercase, so a `'vnd'` here is a corrupt row to surface, not to forgive.
  static CurrencyCode? fromCode(String code) {
    for (final candidate in CurrencyCode.values) {
      if (candidate.code == code) return candidate;
    }
    return null;
  }
}
