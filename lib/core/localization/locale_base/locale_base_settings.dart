part of 'locale_base.dart';

/// Settings tab. The language names themselves are NOT here — a language is always written in its own language, so `GPLocale.displayName` owns them.
abstract class GPLocaleBaseSettings {
  const GPLocaleBaseSettings();

  String get title;
  String get language;
}
