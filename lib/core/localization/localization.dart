import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/localization/locale_store.dart';
import 'package:ghpockit/core/localization/locale_vi/locale_vi.dart';

/// Holds the active language and notifies listeners when it changes.
///
/// A registered `get_it` singleton, not a static `GPLocalization.instance`. Same reason as `GPClock` and `GPUuidGenerator` in ADR-0002: a global
/// mutable singleton cannot be faked, so every widget test would either run in English or leak the previous test's language into the next one.
///
/// A `ChangeNotifier` because changing language must repaint the whole app — five tab branches, all of them alive under the stateful shell
/// (ADR-0003). `GPApp` listens and rebuilds `MaterialApp` so `GPLocalizationScope` and Material's own `locale` move together.
class GPLocalization extends ChangeNotifier {
  GPLocalization({required GPLocaleStore store}) : _store = store;

  static const Map<GPLocale, GPLocaleBase> _strings = <GPLocale, GPLocaleBase>{
    GPLocale.en: GPLocaleEn(),
    GPLocale.vi: GPLocaleVi(),
  };

  final GPLocaleStore _store;

  /// The active strings. Never null — before [init] runs this is the fallback language, so a widget built early cannot see a half-initialised app.
  GPLocaleBase get current => _current;
  GPLocaleBase _current = _strings[GPLocale.fallback]!;

  GPLocale get locale => _current.locale;

  /// Whether the user has made an explicit choice, as opposed to following the device.
  bool get isExplicit => _isExplicit;
  bool _isExplicit = false;

  /// Resolves the starting language: the stored choice if there is one, otherwise the device language, otherwise [GPLocale.fallback].
  ///
  /// Called from `bootstrap()` before `runApp`, so the first frame is already in the right language — no flash of English.
  Future<void> init({Locale? deviceLocale}) async {
    final stored = await _store.read();
    if (stored != null) {
      _apply(stored, isExplicit: true);
      return;
    }
    _apply(deviceLocale == null ? GPLocale.fallback : GPLocale.fromPlatform(deviceLocale), isExplicit: false);
  }

  /// Records an explicit choice by the user and repaints.
  ///
  /// The UI is updated before the write is awaited: the store is local-only, so there is no failure mode where the language must be rolled back, and
  /// making the user wait on a disk write to see a tapped language would be a self-inflicted delay.
  Future<void> changeLocale(GPLocale locale) async {
    if (locale == _current.locale && _isExplicit) {
      return;
    }
    _apply(locale, isExplicit: true);
    await _store.write(locale);
  }

  void _apply(GPLocale locale, {required bool isExplicit}) {
    final next = _strings[locale]!;
    final changed = !identical(next, _current) || isExplicit != _isExplicit;
    _current = next;
    _isExplicit = isExplicit;
    if (changed) {
      notifyListeners();
    }
  }
}
