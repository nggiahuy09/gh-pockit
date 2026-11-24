import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:supabase/supabase.dart';

import '../../../../core/database/database.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/security/secure_store.dart';
import '../../../../core/utils/clock.dart';

/// Keeps the session across launches and pauses refresh in the background (ADR-0039). Logs types only.
final class SupabaseSessionKeeper {
  SupabaseSessionKeeper({required GoTrueClient auth, required GPClock clock, required GPAppDatabase database, required GPAppLogger logger, required GPSecureStore store})
    : _auth = auth,
      _clock = clock,
      _database = database,
      _logger = logger,
      _store = store;

  static const sessionKey = 'auth.session';

  /// In `settings`: a Keychain item outlives an uninstall, the database does not.
  static const keptMarkerKey = 'auth.session_kept';

  final GoTrueClient _auth;
  final GPClock _clock;
  final GPAppDatabase _database;
  final GPAppLogger _logger;
  final GPSecureStore _store;

  StreamSubscription<AuthState>? _subscription;
  AppLifecycleListener? _lifecycle;

  // Sequential: a sign-out's delete never lands before the write it follows.
  Future<void> _writes = Future.value();

  @visibleForTesting
  Future<void> get idle => _writes;

  void start() {
    _subscription ??= _auth.onAuthStateChange.listen(_handleAuthState, onError: _handleAuthError);
    _lifecycle ??= AppLifecycleListener(onResume: _auth.startAutoRefresh, onPause: _auth.stopAutoRefresh);
  }

  /// No network call; an expired token is renewed by the refresh ticker.
  Future<void> restore() async {
    final String? stored;
    try {
      stored = await _store.read(sessionKey);
    } on Exception catch (error) {
      _logger.warn('kept session read failed', fields: {'error': error.runtimeType.toString()});
      return;
    }
    if (stored == null) return;

    if (!await _hasMarker()) {
      _logger.info('kept session from a previous install dropped');
      await _deleteSession();
      return;
    }

    try {
      await _auth.setInitialSession(stored);
    } on Exception catch (error) {
      _logger.warn('kept session unreadable, dropped', fields: {'error': error.runtimeType.toString()});
      await _deleteSession();
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _lifecycle?.dispose();
    await _writes;
  }

  void _handleAuthState(AuthState state) {
    switch (state.event) {
      case AuthChangeEvent.signedIn || AuthChangeEvent.tokenRefreshed || AuthChangeEvent.userUpdated || AuthChangeEvent.mfaChallengeVerified:
        final session = state.session;
        if (session != null) _enqueue(() => _keep(session));
      case AuthChangeEvent.signedOut:
        _enqueue(_deleteSession);
      // Named, not a wildcard, so a new event must be placed.
      // ignore: deprecated_member_use
      case AuthChangeEvent.initialSession || AuthChangeEvent.passwordRecovery || AuthChangeEvent.userDeleted:
        break;
    }
  }

  // A failed refresh while offline; the session stays.
  void _handleAuthError(Object error) => _logger.debug('auth state error', fields: {'error': error.runtimeType.toString()});

  void _enqueue(Future<void> Function() write) => _writes = _writes.then((_) => write());

  /// Marker first: a marker without a session restores nothing.
  Future<void> _keep(Session session) async {
    try {
      await _database.into(_database.settingsTable).insertOnConflictUpdate(SettingsTableCompanion.insert(key: keptMarkerKey, value: '1', updatedAt: _clock.nowEpochMillis()));
      await _store.write(sessionKey, jsonEncode(session.toJson()));
    } on Exception catch (error) {
      // The session still works in memory.
      _logger.warn('session keep failed', fields: {'error': error.runtimeType.toString()});
    }
  }

  Future<void> _deleteSession() async {
    try {
      await _store.delete(sessionKey);
    } on Exception catch (error) {
      _logger.warn('kept session delete failed', fields: {'error': error.runtimeType.toString()});
    }
  }

  Future<bool> _hasMarker() async {
    try {
      final row = await (_database.select(_database.settingsTable)..where((t) => t.key.equals(keptMarkerKey))).getSingleOrNull();
      return row != null;
    } on Exception catch (error) {
      _logger.warn('session marker read failed', fields: {'error': error.runtimeType.toString()});
      return false;
    }
  }
}
