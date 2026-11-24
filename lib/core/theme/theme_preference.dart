import 'package:flutter/material.dart';

/// Stored by [storageValue], never the Dart name, so a rename is not a data migration.
enum GPThemePreference {
  system('system', ThemeMode.system),
  light('light', ThemeMode.light),
  dark('dark', ThemeMode.dark);

  const GPThemePreference(this.storageValue, this.themeMode);

  final String storageValue;
  final ThemeMode themeMode;

  /// Null for an unknown value: a corrupt row must not become a choice the user never made.
  static GPThemePreference? fromStorage(String value) => values.where((preference) => preference.storageValue == value).firstOrNull;
}
