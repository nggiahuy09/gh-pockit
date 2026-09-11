import 'package:ghpockit/core/localization/locale.dart';

/// Where the user's language choice is remembered between launches.
///
/// An interface with no persistent implementation yet, on purpose (ADR-0004). The app has no database until W2 and no settings screen until W23, so
/// the alternative today would be adding `shared_preferences` for one key and then owning two settings stores once Drift arrives. W2 adds a
/// local-only `settings` table and a `GPDriftLocaleStore`; nothing outside this file changes when it does.
///
/// Local-only by design: the choice never enters the outbox and never syncs. A language belongs to a device, not to an account — a phone kept in
/// Vietnamese and a work tablet kept in English must not fight over it, and a sync round trip must never sit between a tap and the UI repainting.
abstract class GPLocaleStore {
  const GPLocaleStore();

  /// The stored choice, or `null` when the user has never picked one — which is not the same as "English": `null` means *follow the device*.
  Future<GPLocale?> read();

  Future<void> write(GPLocale locale);
}

/// The implementation used until W2 wires Drift in.
///
/// Remembers the choice for the life of the process, not across launches. Also what tests use, so a test never touches real storage.
class GPInMemoryLocaleStore extends GPLocaleStore {
  GPInMemoryLocaleStore({GPLocale? initial}) : _locale = initial;

  GPLocale? _locale;

  @override
  Future<GPLocale?> read() async => _locale;

  @override
  Future<void> write(GPLocale locale) async => _locale = locale;
}
