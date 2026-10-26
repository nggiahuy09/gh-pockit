import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';

import 'locale.dart';
import 'locale_base/locale_base.dart';
import 'locale_en/locale_en.dart';
import 'locale_store.dart';
import 'locale_vi/locale_vi.dart';

final class GPLocalization extends ChangeNotifier {
  GPLocalization(this._store);

  final GPLocaleStore _store;

  static const Map<GPLocale, GPLocaleBase> _strings = {GPLocale.en: GPLocaleEn(), GPLocale.vi: GPLocaleVi()};

  /// The fallback language until [init] runs.
  GPLocaleBase get current => _current;
  GPLocaleBase _current = _strings[GPLocale.fallback]!;

  /// Whether the user picked a language, as opposed to following the device.
  bool get isExplicit => _isExplicit;
  var _isExplicit = false;

  GPLocale get locale => _current.locale;

  Future<void> init([Locale? deviceLocale]) async {
    final stored = await _store.read();
    final device = deviceLocale == null ? GPLocale.fallback : GPLocale.fromPlatform(deviceLocale);
    _apply(stored ?? device, isExplicit: stored != null);
  }

  /// Repaints before the write lands: the store is local-only, so there is nothing to roll back.
  Future<void> changeLocale(GPLocale locale) async {
    if (locale == _current.locale && _isExplicit) return;

    _apply(locale, isExplicit: true);
    await _store.write(locale);
  }

  void _apply(GPLocale locale, {required bool isExplicit}) {
    final next = _strings[locale]!;
    final isChanged = !identical(next, _current) || isExplicit != _isExplicit;
    _current = next;
    _isExplicit = isExplicit;
    if (isChanged) notifyListeners();
  }
}
