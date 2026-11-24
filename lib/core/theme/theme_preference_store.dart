import 'theme_preference.dart';

/// Local-only, like the language: a device setting, never synced, kept on sign-out (ADR-0043).
abstract class GPThemePreferenceStore {
  const GPThemePreferenceStore();

  /// Null means never chosen: follow the system.
  Future<GPThemePreference?> read();

  Future<void> write(GPThemePreference preference);
}
