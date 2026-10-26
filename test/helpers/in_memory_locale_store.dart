import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/locale_store.dart';

/// Forgets the choice on restart.
final class InMemoryLocaleStore extends GPLocaleStore {
  InMemoryLocaleStore([this._locale]);

  GPLocale? _locale;

  @override
  Future<GPLocale?> read() async => _locale;

  @override
  Future<void> write(GPLocale locale) async => _locale = locale;
}
