import 'package:flutter/material.dart';

import 'theme_preference.dart';
import 'theme_preference_store.dart';

/// Must stay a singleton: `GPApp` repaints from it. [init] runs before the first frame, so a dark choice never flashes light.
final class GPAppearance extends ChangeNotifier {
  GPAppearance(this._store);

  final GPThemePreferenceStore _store;

  GPThemePreference get preference => _preference;
  GPThemePreference _preference = GPThemePreference.system;

  ThemeMode get themeMode => _preference.themeMode;

  Future<void> init() async => _apply(await _store.read() ?? GPThemePreference.system);

  /// Repaints before the write lands: local-only, so there is nothing to roll back.
  Future<void> change(GPThemePreference preference) async {
    if (preference == _preference) return;

    _apply(preference);
    await _store.write(preference);
  }

  void _apply(GPThemePreference preference) {
    if (preference == _preference) return;

    _preference = preference;
    notifyListeners();
  }
}
