import 'dart:ui' show Locale;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/localization/drift_locale_store.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/logging/app_logger.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/recording_logger.dart';

void main() {
  late GPAppDatabase db;
  late FakeClock clock;
  late RecordingLogger logger;
  late GPDriftLocaleStore store;

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    clock = FakeClock();
    logger = RecordingLogger(clock: clock);
    store = GPDriftLocaleStore(database: db, clock: clock, logger: logger);
  });

  tearDown(() async {
    await db.close();
  });

  test('returns null when the user has never chosen', () async {
    expect(await store.read(), isNull);
  });

  test('a written choice survives a new store over the same database', () async {
    await store.write(GPLocale.vi);

    // A second instance stands in for the next launch: nothing is cached in the object.
    final afterRestart = GPDriftLocaleStore(database: db, clock: clock, logger: logger);

    expect(await afterRestart.read(), GPLocale.vi);
  });

  test('overwrites an existing choice instead of throwing', () async {
    await store.write(GPLocale.vi);
    clock.advance(const Duration(minutes: 1));
    await store.write(GPLocale.en);

    // `key` is the primary key: a plain insert would throw on the second write.
    expect(await store.read(), GPLocale.en);
    expect(await db.select(db.settingsTable).get(), hasLength(1));
  });

  test('stores the language code under a namespaced key, with the clock time', () async {
    await store.write(GPLocale.vi);

    final row = await db.select(db.settingsTable).getSingle();

    expect(row.key, 'locale.selected');
    // The language code, not the enum constant's name: renaming a constant must not become a data migration.
    expect(row.value, 'vi');
    expect(row.updatedAt, clock.nowEpochMillis());
  });

  test('treats an unrecognised stored code as no choice at all', () async {
    await db.into(db.settingsTable).insert(SettingsTableCompanion.insert(key: 'locale.selected', value: 'fr', updatedAt: clock.nowEpochMillis()));

    // Not `GPLocale.en`, which `GPLocale.fromLanguageCode` would return: that would be an explicit English choice the user never made.
    expect(await store.read(), isNull);
  });

  test('GPLocalization boots into the stored language rather than the device one', () async {
    await store.write(GPLocale.vi);

    final localization = GPLocalization(
      store: GPDriftLocaleStore(database: db, clock: clock, logger: logger),
    );
    await localization.init(deviceLocale: const Locale('en'));

    expect(localization.locale, GPLocale.vi);
    expect(localization.isExplicit, isTrue);
  });

  group('when storage is unreachable', () {
    // A dropped table stands in for a database that cannot answer: it raises the same `SqliteException` a corrupt file would.
    setUp(() => db.customStatement('DROP TABLE settings'));

    test('read degrades to no stored choice instead of taking the app down', () async {
      expect(await store.read(), isNull);
      expect(logger.last.level, GPLogLevel.warn);
    });

    test('write logs and swallows, so a tapped language does not become an uncaught error', () async {
      // `error`, not `warn` like a failed read: the user's deliberate choice did not stick.
      await expectLater(store.write(GPLocale.vi), completes);
      expect(logger.last.level, GPLogLevel.error);
    });

    test('logs nothing a language choice could leak', () async {
      await store.write(GPLocale.vi);

      expect(logger.last.fields, {'key': 'locale.selected'});
    });
  });
}
