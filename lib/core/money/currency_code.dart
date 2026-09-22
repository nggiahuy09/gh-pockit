/// The currencies the app knows how to interpret, and the two facts it needs about each: how many digits of a `Money.minorUnits` amount sit after the
/// decimal point, and what symbol to print.
///
/// **This is the membership half of the split `Money` describes.** `Money` validates the *shape* of a code — three A–Z letters — and deliberately accepts
/// `XYZ`, because hard-coding a currency list into the value object would mean a new currency is a change to the type every feature imports. This enum is
/// the other half: whether a well-formed code is one we can actually render, and with what exponent. Nothing here is needed to *hold* an amount; it is
/// needed to *show* one, which is why it arrives at W3 T4 with `GPMoneyFormatter` and not at W2 with `Money`.
///
/// **Two entries, not an ISO-4217 table.** Multi-currency is W37+ and the exponent is the only per-currency fact the formatter consumes today. A generated
/// table of 180 currencies would be 178 rows nothing reads, and every one of them a claim about a symbol we have never rendered. Adding a currency here is
/// a one-line change plus a test; that is the right cost for something a user picks from a list of two.
///
/// **Unprefixed, in `core/`,** for the same reason as `Money` (§3): this is a domain value, not infrastructure — `domain/` names a currency, and it sits in
/// `core/money/` only because every feature needs it. The formatter beside it *is* infrastructure and carries the `GP`.
enum CurrencyCode {
  /// Vietnamese dong. Exponent 0 — there is no subunit in circulation, so `1500000` is one and a half million dong, not fifteen thousand.
  vnd(code: 'VND', exponent: 0, symbol: '₫'),

  /// US dollar. Exponent 2 — `1234` is $12.34.
  usd(code: 'USD', exponent: 2, symbol: r'$');

  const CurrencyCode({required this.code, required this.exponent, required this.symbol});

  /// The ISO-4217 alphabetic code, uppercase. The form stored in `accounts.currency_code` and carried by `Money.currencyCode`.
  final String code;

  /// ISO-4217 minor unit exponent: how many of the amount's trailing digits are fractional. 0 for VND, 2 for USD.
  final int exponent;

  /// What to print beside the amount. Placement is the *locale's* business, not the currency's — `GPMoneyFormatter` asks `intl` where it goes, which is why
  /// the same `₫` lands before the digits in English and after them in Vietnamese.
  final String symbol;

  /// Looks up a code, returning null when it is not one of ours.
  ///
  /// Null rather than a throw, and case-sensitive rather than forgiving. Every caller today is a formatter running inside `build()`, where an unknown code
  /// is a row from a newer build or a corrupt one — neither is worth a red screen, and both are worth rendering honestly. `'vnd'` returns null on purpose:
  /// `Money` already rejects lowercase, so a lowercase code reaching here is the same corruption by another route, and silently accepting it would hide it.
  static CurrencyCode? fromCode(String code) {
    for (final candidate in CurrencyCode.values) {
      if (candidate.code == code) return candidate;
    }
    return null;
  }
}
