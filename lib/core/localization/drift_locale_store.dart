import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_store.dart';
import 'package:ghpockit/core/logging/app_logger.dart';
import 'package:ghpockit/core/utils/clock.dart';

/// The persistent [GPLocaleStore] — the W1 debt ADR-0004 left open, paid at W2 once a `settings` table existed to pay it with.
///
/// Until this class was wired, `GPInMemoryLocaleStore` was bound in DI, which meant the language a user picked survived exactly as long as the process:
/// a tap changed the UI, a restart threw it away. That is the entire bug.
///
/// **In its own file rather than beside the interface.** `locale_store.dart` is imported by `localization.dart`, which is imported by the whole widget
/// tree; putting a `GPAppDatabase` import there would drag the database into everything that renders a string. The interface stays dependency-free and the
/// implementation carries its own weight.
///
/// Local-only, and that is a decision rather than an omission (ADR-0004): the row lives in `settings`, which has no `owner_id`, no `version` and no
/// `deleted_at`, never enters the outbox and never syncs. A language belongs to a device — a phone kept in Vietnamese and a work tablet kept in English
/// must not fight over it — and no sync round trip may sit between a tap and the UI repainting.
///
/// **Neither method lets a storage failure escape**, which is the one thing this class had to add that the in-memory store never needed. `bootstrap()`
/// awaits `GPLocalization.init()` before `runApp`, so before this store existed that call could not fail; now it reaches sqlite, and an unreadable database
/// would take the whole app down with no UI to say so. A remembered language is the least important state in the app and must never be the reason it does
/// not start. So a failed read degrades to "no stored choice" — which is exactly what a fresh install looks like — and a failed write degrades to a choice
/// that applies now and is forgotten later. Both are logged; neither is silent.
class GPDriftLocaleStore extends GPLocaleStore {
  GPDriftLocaleStore({required GPAppDatabase database, required GPClock clock, required GPAppLogger logger}) : _db = database, _clock = clock, _logger = logger;

  /// The `settings` key this store owns. Dotted namespace as that table's doc requires, so a later feature cannot collide by picking the same short word.
  static const String storageKey = 'locale.selected';

  final GPAppDatabase _db;
  final GPClock _clock;
  final GPAppLogger _logger;

  /// Reads the stored choice, or null when there is none — and null means *follow the device*, not English.
  @override
  Future<GPLocale?> read() async {
    final SettingRow? row;
    try {
      row = await (_db.select(_db.settingsTable)..where((t) => t.key.equals(storageKey))).getSingleOrNull();
    } on Exception catch (error, stackTrace) {
      // `on Exception`, not `on Object`: sqlite failures, a missing plugin and a broken file all arrive as exceptions, while an `Error` is a bug in this
      // app rather than a storage problem and should keep crashing loudly. `warn` rather than `error` because the app carries on exactly as it would for
      // a user who has never chosen — degraded, not broken.
      _logger.warn('locale read failed, falling back to the device language', fields: {'key': storageKey}, error: error, stackTrace: stackTrace);
      return null;
    }

    if (row == null) {
      return null;
    }

    // Matched exactly rather than through `GPLocale.fromLanguageCode`, which falls back to `GPLocale.en` for anything it does not ship. That fallback is
    // right at the device-locale boundary and wrong here: it would turn a row left behind by a language we dropped — or a value corrupted by anything —
    // into an explicit English choice the user never made, and `GPLocalization.isExplicit` would then stop the device language from ever applying again.
    // Unrecognised means "no usable choice", which is what null already means.
    for (final candidate in GPLocale.values) {
      if (candidate.languageCode == row.value) {
        return candidate;
      }
    }
    return null;
  }

  @override
  Future<void> write(GPLocale locale) async {
    try {
      await _db
          .into(_db.settingsTable)
          .insertOnConflictUpdate(
            // Upsert, not insert: `key` is the primary key, so the second language change of a session would throw on a plain insert. `insertOnConflictUpdate`
            // is the one write mode that makes "remember this choice" idempotent.
            SettingsTableCompanion.insert(
              key: storageKey,
              value: locale.languageCode,
              // Epoch millis from `GPClock`, never `DateTime.now()` (§6, §8) — the column exists so a later settings screen can say when something was changed.
              updatedAt: _clock.nowEpochMillis(),
            ),
          );
    } on Exception catch (error, stackTrace) {
      // `error`, unlike the read above: the user did something deliberate and it did not stick. Swallowed rather than rethrown because the only caller is
      // `SettingsPage`, which fires `changeLocale` with `unawaited` — an escaping exception there becomes an uncaught async error routed through
      // `PlatformDispatcher.onError`, which logs the same thing with a worse message and no idea which setting it was.
      _logger.error('locale write failed, the choice will not survive a restart', fields: {'key': storageKey}, error: error, stackTrace: stackTrace);
    }
  }
}
