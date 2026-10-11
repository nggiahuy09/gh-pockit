import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_store.dart';
import 'package:ghpockit/core/logging/app_logger.dart';
import 'package:ghpockit/core/utils/clock.dart';

/// Neither method lets a storage failure escape: `init()` runs before `runApp`, and a language must never stop the app starting. A failed read is "no
/// stored choice", a failed write a choice forgotten on restart (ADR-0004).
///
/// Kept out of `locale_store.dart`, which the whole widget tree imports, so the database import stays here.
class GPDriftLocaleStore extends GPLocaleStore {
  GPDriftLocaleStore({required GPAppDatabase database, required GPClock clock, required GPAppLogger logger}) : _db = database, _clock = clock, _logger = logger;

  static const String storageKey = 'locale.selected';

  final GPAppDatabase _db;
  final GPClock _clock;
  final GPAppLogger _logger;

  @override
  Future<GPLocale?> read() async {
    final SettingRow? row;
    try {
      row = await (_db.select(_db.settingsTable)..where((t) => t.key.equals(storageKey))).getSingleOrNull();
    } on Exception catch (error, stackTrace) {
      // Not `on Object`: an `Error` is a bug, not a storage problem, and should still crash. `warn`: the app carries on as for a user who never chose.
      _logger.warn('locale read failed, falling back to the device language', fields: {'key': storageKey}, error: error, stackTrace: stackTrace);
      return null;
    }

    if (row == null) {
      return null;
    }

    // Not `GPLocale.fromLanguageCode`: its English fallback would turn a dropped or corrupt value into an explicit choice the user never made, and
    // `isExplicit` would then shut out the device language for good.
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
            SettingsTableCompanion.insert(
              key: storageKey,
              value: locale.languageCode,
              updatedAt: _clock.nowEpochMillis(),
            ),
          );
    } on Exception catch (error, stackTrace) {
      // `error`: a deliberate choice did not stick. Swallowed: `changeLocale` is fired unawaited, so a rethrow only reaches `PlatformDispatcher.onError`.
      _logger.error('locale write failed, the choice will not survive a restart', fields: {'key': storageKey}, error: error, stackTrace: stackTrace);
    }
  }
}
