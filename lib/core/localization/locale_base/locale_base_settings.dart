part of 'locale_base.dart';

/// No language names here: each is written in its own language, by `GPLocale.displayName`.
abstract class GPLocaleBaseSettings {
  const GPLocaleBaseSettings();

  String get title;
  String get language;
  String get debugTitle;
  String get debugAddSample;
  String get debugSampleAdded;
  String get debugSampleAccountName;
  String get debugSampleNote;
  String get debugSeedDataset;
  String debugDatasetSeeded(int count);
}
