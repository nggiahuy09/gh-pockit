import 'dart:ui' show Locale;

/// The languages the app ships. Adding one here is a compile error until a matching `GPLocaleBase` implementation exists.
///
/// An enum rather than a bare `String` language code, so switching on the active language is exhaustive and a typo (`'vn'` instead of `'vi'`) cannot
/// reach the running app.
enum GPLocale {
  en(languageCode: 'en', displayName: 'English'),
  vi(languageCode: 'vi', displayName: 'Tiếng Việt');

  const GPLocale({required this.languageCode, required this.displayName});

  /// ISO 639-1 code. The only form persisted or compared.
  final String languageCode;

  /// How this language names itself.
  ///
  /// Deliberately not a localized string: a language picker writes every option in its own language, so a Vietnamese speaker looking at an English UI
  /// still recognises "Tiếng Việt". Translating these would be a bug, not a feature.
  final String displayName;

  /// The default when the device asks for a language we do not ship.
  static const GPLocale fallback = GPLocale.en;

  /// Resolves a platform [Locale] to a shipped language.
  ///
  /// Country is ignored on purpose: `en_US`, `en_GB` and `en_AU` are one translation here, and pretending otherwise would mean three files that never
  /// differ. Region-specific number and currency formatting is a separate concern and stays with `intl`.
  static GPLocale fromPlatform(Locale locale) => fromLanguageCode(locale.languageCode);

  /// Resolves a language code, falling back to [fallback] for anything unsupported.
  static GPLocale fromLanguageCode(String? code) {
    final normalized = code?.trim().toLowerCase();
    for (final candidate in GPLocale.values) {
      if (candidate.languageCode == normalized) {
        return candidate;
      }
    }
    return fallback;
  }

  /// The Flutter [Locale] handed to `MaterialApp`, so Material's own widgets follow the same language.
  Locale toPlatformLocale() => Locale(languageCode);
}
