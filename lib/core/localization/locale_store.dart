import 'package:ghpockit/core/localization/locale.dart';

/// Local-only by design: a language belongs to a device, not an account, so it never enters the outbox or syncs (ADR-0004).
abstract class GPLocaleStore {
  const GPLocaleStore();

  /// `null` means never chosen, so follow the device — not English.
  Future<GPLocale?> read();

  Future<void> write(GPLocale locale);
}

/// A test double: forgets the choice on restart.
class GPInMemoryLocaleStore extends GPLocaleStore {
  GPInMemoryLocaleStore({GPLocale? initial}) : _locale = initial;

  GPLocale? _locale;

  @override
  Future<GPLocale?> read() async => _locale;

  @override
  Future<void> write(GPLocale locale) async => _locale = locale;
}
