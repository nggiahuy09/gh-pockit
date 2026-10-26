/// What the app can render. `Money` checks only a code's shape, so a well-formed code may still be missing here (ADR-0007).
enum CurrencyCode {
  /// ISO-4217 gives VND no minor unit: `1500000` is 1.5 million dong.
  vnd('VND', '₫', 0),

  usd('USD', r'$', 2);

  const CurrencyCode(this.code, this.symbol, this.exponent);

  final String code;

  /// Placement comes from the locale via `intl`, not from the currency.
  final String symbol;

  /// How many trailing digits of `Money.minorUnits` are fractional.
  final int exponent;

  /// Case-sensitive on purpose: `Money` rejects lowercase, so a `'vnd'` here is a corrupt row to surface, not to forgive.
  static CurrencyCode? fromCode(String code) => values.where((currency) => currency.code == code).firstOrNull;
}
