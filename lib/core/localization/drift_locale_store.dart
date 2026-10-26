import '../database/database.dart';
import '../logging/app_logger.dart';
import '../utils/clock.dart';
import 'locale.dart';
import 'locale_store.dart';

/// No storage failure escapes: `init()` runs before `runApp`, and a language must never stop the app starting (ADR-0004). Kept out of
/// `locale_store.dart`, which the whole widget tree imports, so the database import stays here.
final class GPDriftLocaleStore extends GPLocaleStore {
  const GPDriftLocaleStore({required GPClock clock, required GPAppDatabase database, required GPAppLogger logger}) : _clock = clock, _database = database, _logger = logger;

  final GPClock _clock;
  final GPAppDatabase _database;
  final GPAppLogger _logger;

  static const storageKey = 'locale.selected';

  @override
  Future<GPLocale?> read() async {
    final SettingRow? row;
    try {
      row = await (_database.select(_database.settingsTable)..where((t) => t.key.equals(storageKey))).getSingleOrNull();
    } on Exception catch (error, stackTrace) {
      _logger.warn('locale read failed, falling back to the device language', fields: {'key': storageKey}, error: error, stackTrace: stackTrace);
      return null;
    }

    // Not `GPLocale.fromLanguageCode`: its English fallback would turn a corrupt value into an explicit choice the user never made.
    return row == null ? null : GPLocale.values.where((locale) => locale.languageCode == row?.value).firstOrNull;
  }

  @override
  Future<void> write(GPLocale locale) async {
    try {
      await _database
          .into(_database.settingsTable)
          .insertOnConflictUpdate(SettingsTableCompanion.insert(key: storageKey, value: locale.languageCode, updatedAt: _clock.nowEpochMillis()));
    } on Exception catch (error, stackTrace) {
      // Swallowed: `changeLocale` is fired unawaited, so a rethrow only reaches `PlatformDispatcher.onError`.
      _logger.error('locale write failed, the choice will not survive a restart', fields: {'key': storageKey}, error: error, stackTrace: stackTrace);
    }
  }
}
