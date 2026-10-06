import 'dart:ui' show Locale;

/// A new value compiles without its strings: register a `GPLocaleBase` for it in `GPLocalization`, or the lookup throws at runtime.
enum GPLocale {
  en(languageCode: 'en', displayName: 'English'),
  vi(languageCode: 'vi', displayName: 'Tiếng Việt');

  const GPLocale({required this.languageCode, required this.displayName});

  /// ISO 639-1. The only form persisted or compared.
  final String languageCode;

  /// The language's name for itself. Never translate it: a picker shows every option in its own language.
  final String displayName;

  static const GPLocale fallback = GPLocale.en;

  /// Ignores the country on purpose: `en_US` and `en_GB` are one translation; regional number formats belong to `intl`.
  static GPLocale fromPlatform(Locale locale) => fromLanguageCode(locale.languageCode);

  /// Anything unsupported, null included, resolves to [fallback].
  static GPLocale fromLanguageCode(String? code) {
    final normalized = code?.trim().toLowerCase();
    for (final candidate in GPLocale.values) {
      if (candidate.languageCode == normalized) {
        return candidate;
      }
    }
    return fallback;
  }

  Locale toPlatformLocale() => Locale(languageCode);
}
