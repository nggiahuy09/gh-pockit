import 'package:ghpockit/core/theme/theme_preference.dart';
import 'package:ghpockit/core/theme/theme_preference_store.dart';

/// Forgets the choice on restart.
final class InMemoryThemePreferenceStore extends GPThemePreferenceStore {
  InMemoryThemePreferenceStore([this.stored]);

  GPThemePreference? stored;

  @override
  Future<GPThemePreference?> read() async => stored;

  @override
  Future<void> write(GPThemePreference preference) async => stored = preference;
}
