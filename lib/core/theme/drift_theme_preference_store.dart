import '../database/database.dart';
import '../logging/app_logger.dart';
import '../utils/clock.dart';
import 'theme_preference.dart';
import 'theme_preference_store.dart';

/// No storage failure escapes: a theme must never stop the app starting.
final class GPDriftThemePreferenceStore extends GPThemePreferenceStore {
  const GPDriftThemePreferenceStore({required GPClock clock, required GPAppDatabase database, required GPAppLogger logger})
    : _clock = clock,
      _database = database,
      _logger = logger;

  final GPClock _clock;
  final GPAppDatabase _database;
  final GPAppLogger _logger;

  static const storageKey = 'theme.mode';

  @override
  Future<GPThemePreference?> read() async {
    try {
      final row = await (_database.select(_database.settingsTable)..where((t) => t.key.equals(storageKey))).getSingleOrNull();
      return row == null ? null : GPThemePreference.fromStorage(row.value);
    } on Exception catch (error, stackTrace) {
      _logger.warn('theme read failed, following the system', fields: {'key': storageKey}, error: error, stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Future<void> write(GPThemePreference preference) async {
    try {
      await _database
          .into(_database.settingsTable)
          .insertOnConflictUpdate(SettingsTableCompanion.insert(key: storageKey, value: preference.storageValue, updatedAt: _clock.nowEpochMillis()));
    } on Exception catch (error, stackTrace) {
      // Swallowed: the change is fired unawaited, and the screen already shows it.
      _logger.error('theme write failed, the choice will not survive a restart', fields: {'key': storageKey}, error: error, stackTrace: stackTrace);
    }
  }
}
