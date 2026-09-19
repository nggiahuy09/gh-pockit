import 'package:ghpockit/core/localization/locale.dart';

/// Where the user's language choice is remembered between launches.
///
/// Implemented by `GPDriftLocaleStore` since W2 T4. The interface was written first and left without a persistent implementation on purpose (ADR-0004):
/// the app had no database until W2, and adding `shared_preferences` for one key would have meant owning two settings stores once Drift arrived. The
/// prediction that came with that trade — that landing persistence would change one line of wiring in `injector.dart` and nothing else — is what actually
/// happened, which is the only reason the wait was cheap.
///
/// Local-only by design: the choice never enters the outbox and never syncs. A language belongs to a device, not to an account — a phone kept in
/// Vietnamese and a work tablet kept in English must not fight over it, and a sync round trip must never sit between a tap and the UI repainting.
abstract class GPLocaleStore {
  const GPLocaleStore();

  /// The stored choice, or `null` when the user has never picked one — which is not the same as "English": `null` means *follow the device*.
  Future<GPLocale?> read();

  Future<void> write(GPLocale locale);
}

/// The non-persistent implementation. Production bound this until W2 T4; it is now the test double.
///
/// Remembers the choice for the life of the process, not across launches — which is exactly what makes it useful to a test that must not touch storage,
/// and exactly what made it a bug in production.
class GPInMemoryLocaleStore extends GPLocaleStore {
  GPInMemoryLocaleStore({GPLocale? initial}) : _locale = initial;

  GPLocale? _locale;

  @override
  Future<GPLocale?> read() async => _locale;

  @override
  Future<void> write(GPLocale locale) async => _locale = locale;
}
