import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/theme/appearance.dart';
import 'package:ghpockit/core/theme/drift_theme_preference_store.dart';
import 'package:ghpockit/core/theme/theme_preference.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/in_memory_theme_preference_store.dart';
import '../../helpers/recording_logger.dart';

void main() {
  group('GPThemePreference', () {
    test('reads back what it stores, and maps to the Material mode', () {
      for (final preference in GPThemePreference.values) {
        expect(GPThemePreference.fromStorage(preference.storageValue), preference);
      }
      expect(GPThemePreference.dark.themeMode, ThemeMode.dark);
      expect(GPThemePreference.system.themeMode, ThemeMode.system);
    });

    test('an unknown stored value is no choice at all', () {
      expect(GPThemePreference.fromStorage('sepia'), isNull);
    });
  });

  group('GPAppearance', () {
    test('follows the system until a choice is stored', () async {
      final appearance = GPAppearance(InMemoryThemePreferenceStore());

      await appearance.init();

      expect(appearance.preference, GPThemePreference.system);
      expect(appearance.themeMode, ThemeMode.system);
    });

    test('starts on the stored choice', () async {
      final appearance = GPAppearance(InMemoryThemePreferenceStore(GPThemePreference.dark));

      await appearance.init();

      expect(appearance.themeMode, ThemeMode.dark);
    });

    test('a change repaints at once and is stored; the same choice again does nothing', () async {
      final store = InMemoryThemePreferenceStore();
      final appearance = GPAppearance(store);
      var notified = 0;
      appearance.addListener(() => notified++);

      await appearance.change(GPThemePreference.light);
      await appearance.change(GPThemePreference.light);

      expect(appearance.preference, GPThemePreference.light);
      expect(store.stored, GPThemePreference.light);
      expect(notified, 1);
    });
  });

  group('GPDriftThemePreferenceStore', () {
    late GPAppDatabase db;
    late RecordingLogger logger;
    late GPDriftThemePreferenceStore store;

    setUp(() {
      db = GPAppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
      logger = RecordingLogger(FakeClock());
      store = GPDriftThemePreferenceStore(clock: FakeClock(), database: db, logger: logger);
    });

    tearDown(() => db.close());

    test('nothing stored is no choice', () async {
      expect(await store.read(), isNull);
    });

    test('writes and reads back, overwriting the last choice', () async {
      await store.write(GPThemePreference.dark);
      await store.write(GPThemePreference.light);

      expect(await store.read(), GPThemePreference.light);
    });

    test('a corrupt row follows the system rather than guess', () async {
      await db.into(db.settingsTable).insert(SettingsTableCompanion.insert(key: GPDriftThemePreferenceStore.storageKey, value: 'sepia', updatedAt: 0));

      expect(await store.read(), isNull);
    });

    test('a database that cannot be read or written never throws', () async {
      await db.customStatement('DROP TABLE settings');

      expect(await store.read(), isNull);
      await store.write(GPThemePreference.dark);
      expect(logger.records.map((record) => record.message), ['theme read failed, following the system', 'theme write failed, the choice will not survive a restart']);
    });
  });
}
