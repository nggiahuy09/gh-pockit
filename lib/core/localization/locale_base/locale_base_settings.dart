part of 'locale_base.dart';

/// No language names here: each is written in its own language, by `GPLocale.displayName`.
abstract class GPLocaleBaseSettings {
  const GPLocaleBaseSettings();

  String get title;
  String get language;
}
