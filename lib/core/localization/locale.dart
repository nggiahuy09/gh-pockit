import 'dart:ui' show Locale;

/// A new value compiles without its strings: register a `GPLocaleBase` for it in `GPLocalization`, or the lookup throws at runtime.
enum GPLocale {
  en('English', 'en'),
  vi('Tiếng Việt', 'vi');

  const GPLocale(this.displayName, this.languageCode);

  static const GPLocale fallback = GPLocale.en;

  /// The language's name for itself: a picker shows every option in its own language.
  final String displayName;

  /// ISO 639-1. The only form persisted or compared.
  final String languageCode;

  /// Ignores the country on purpose: `en_US` and `en_GB` are one translation; regional number formats belong to `intl`.
  static GPLocale fromPlatform(Locale locale) => fromLanguageCode(locale.languageCode);

  /// Anything unsupported, null included, resolves to [fallback].
  static GPLocale fromLanguageCode(String? code) {
    final normalized = code?.trim().toLowerCase();
    return values.where((locale) => locale.languageCode == normalized).firstOrNull ?? fallback;
  }

  Locale toPlatformLocale() => Locale(languageCode);
}
