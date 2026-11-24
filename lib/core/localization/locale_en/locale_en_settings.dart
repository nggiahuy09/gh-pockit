part of 'locale_en.dart';

final class GPLocaleEnSettings implements GPLocaleBaseSettings {
  const GPLocaleEnSettings();

  @override
  String get title => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceSystem => 'Match the system';

  @override
  String get appearanceSystemBody => 'Light or dark, as the device is set';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get debugTitle => 'Debug';

  @override
  String get debugAddSample => 'Add a sample transaction';

  @override
  String get debugSampleAdded => 'Sample transaction added.';

  @override
  String get debugSampleAccountName => 'Sample wallet';

  @override
  String get debugSampleNote => 'Sample transaction';

  @override
  String get debugSeedDataset => 'Load the sample dataset';

  @override
  String debugDatasetSeeded(int count) => 'Added $count sample transactions.';
}
