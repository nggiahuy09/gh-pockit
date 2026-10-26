import 'locale.dart';

/// Local-only: a language belongs to a device, not an account, so it never enters the outbox (ADR-0004).
abstract class GPLocaleStore {
  const GPLocaleStore();

  /// Null means never chosen, so follow the device — not English.
  Future<GPLocale?> read();

  Future<void> write(GPLocale locale);
}
