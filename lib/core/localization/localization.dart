import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/localization/locale_store.dart';
import 'package:ghpockit/core/localization/locale_vi/locale_vi.dart';

class GPLocalization extends ChangeNotifier {
  GPLocalization({required GPLocaleStore store}) : _store = store;

  static const Map<GPLocale, GPLocaleBase> _strings = <GPLocale, GPLocaleBase>{
    GPLocale.en: GPLocaleEn(),
    GPLocale.vi: GPLocaleVi(),
  };

  final GPLocaleStore _store;

  /// The fallback language until [init] runs.
  GPLocaleBase get current => _current;
  GPLocaleBase _current = _strings[GPLocale.fallback]!;

  GPLocale get locale => _current.locale;

  /// Whether the user picked a language, as opposed to following the device.
  bool get isExplicit => _isExplicit;
  bool _isExplicit = false;

  Future<void> init({Locale? deviceLocale}) async {
    final stored = await _store.read();
    if (stored != null) {
      _apply(stored, isExplicit: true);
      return;
    }
    _apply(deviceLocale == null ? GPLocale.fallback : GPLocale.fromPlatform(deviceLocale), isExplicit: false);
  }

  /// Repaints before the write lands: the store is local-only, so there is nothing to roll back.
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
