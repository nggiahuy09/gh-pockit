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

/// The W1 debt from ADR-0004, paid at W2 (§ROADMAP W2 flex).
///
/// The bug this closes is small and total: with `GPInMemoryLocaleStore` bound, a user picking Tiếng Việt saw the UI change and saw it revert on the next
/// launch. So the assertions that matter are the ones about *surviving a restart* — modelled here as a second store over the same database — and about the
/// difference between "no choice" and "chose English", which `GPLocalization.isExplicit` turns into whether the device language still applies.
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
    // Null means *follow the device*, which is not the same as English — the distinction the whole store hangs on.
    expect(await store.read(), isNull);
  });

  test('a written choice survives a new store over the same database', () async {
    await store.write(GPLocale.vi);

    // A second instance stands in for the next app launch: nothing is cached in the object, so what comes back came from SQLite.
    final afterRestart = GPDriftLocaleStore(database: db, clock: clock, logger: logger);

    expect(await afterRestart.read(), GPLocale.vi);
  });

  test('overwrites an existing choice instead of throwing', () async {
    await store.write(GPLocale.vi);
    clock.advance(const Duration(minutes: 1));
    await store.write(GPLocale.en);

    // `key` is the primary key, so a plain insert would throw on the second language change of a session. `insertOnConflictUpdate` is what makes
    // "remember this choice" idempotent — and it has to be, because `GPLocalization.changeLocale` does not await the write.
    expect(await store.read(), GPLocale.en);
    expect(await db.select(db.settingsTable).get(), hasLength(1));
  });

  test('stores the language code under a namespaced key, with the clock time', () async {
    await store.write(GPLocale.vi);

    final row = await db.select(db.settingsTable).getSingle();

    expect(row.key, 'locale.selected');
    // The code, not the enum's Dart name or its display name: `GPLocale.vi.toString()` would make renaming an enum constant a silent data migration.
    expect(row.value, 'vi');
    // Epoch millis from `GPClock`, never `DateTime.now()` (§6, §8).
    expect(row.updatedAt, clock.nowEpochMillis());
  });

  test('treats an unrecognised stored code as no choice at all', () async {
    await db.into(db.settingsTable).insert(SettingsTableCompanion.insert(key: 'locale.selected', value: 'fr', updatedAt: clock.nowEpochMillis()));

    // Not `GPLocale.en`, which is what `GPLocale.fromLanguageCode` would return. That fallback is right at the device-locale boundary and wrong here: it
    // would turn a row left behind by a dropped language into an explicit English choice the user never made, and `isExplicit` would then keep the device
    // language from ever applying again. Unrecognised means "no usable choice" — which is what null already means.
    expect(await store.read(), isNull);
  });

  test('GPLocalization boots into the stored language rather than the device one', () async {
    await store.write(GPLocale.vi);

    final localization = GPLocalization(
      store: GPDriftLocaleStore(database: db, clock: clock, logger: logger),
    );
    await localization.init(deviceLocale: const Locale('en'));

    // The end-to-end shape of the fix: `bootstrap()` awaits exactly this before the first frame, so a Vietnamese user on an English phone never sees the
    // app paint English first.
    expect(localization.locale, GPLocale.vi);
    expect(localization.isExplicit, isTrue);
  });

  group('when storage is unreachable', () {
    // A dropped table stands in for a database that cannot answer — a corrupt file, a failed migration, a revoked directory. It surfaces as the same
    // `SqliteException` those do, which is what both paths below are written against.
    setUp(() => db.customStatement('DROP TABLE settings'));

    test('read degrades to no stored choice instead of taking the app down', () async {
      // The regression this guards. `bootstrap()` awaits `GPLocalization.init()` before `runApp`, so an escaping exception here is a dead app with no UI
      // to explain itself — and the state being read is a language preference. Behaving like a fresh install is the correct degradation.
      expect(await store.read(), isNull);
      expect(logger.last.level, GPLogLevel.warn);
    });

    test('write logs and swallows, so a tapped language does not become an uncaught error', () async {
      // `SettingsPage` fires `changeLocale` through `unawaited`, so a throw here would surface as an uncaught async error with no idea which setting it
      // was. `error` level, not `warn`: the user did something deliberate and it did not stick.
      await expectLater(store.write(GPLocale.vi), completes);
      expect(logger.last.level, GPLogLevel.error);
    });

    test('logs nothing a language choice could leak', () async {
      await store.write(GPLocale.vi);

      // Golden rule 9 is about financial payloads, and a locale is not one — but the habit of logging the key rather than the value is what keeps the
      // rule cheap to follow when the same shape reaches a store that does hold money.
      expect(logger.last.fields, {'key': 'locale.selected'});
    });
  });
}
