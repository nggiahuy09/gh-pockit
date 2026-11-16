import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/logging/app_logger.dart';
import 'package:ghpockit/features/auth/data/datasources/supabase_session_keeper.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/gotrue_fixtures.dart';
import '../../../../helpers/in_memory_secure_store.dart';
import '../../../../helpers/recording_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late RecordingLogger logger;
  late GPAppDatabase database;
  late InMemorySecureStore store;

  setUp(() {
    requests = [];
    logger = RecordingLogger(FakeClock());
    database = GPAppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    store = InMemorySecureStore();
  });

  tearDown(() => database.close());

  SupabaseSessionKeeper keeperFor(GoTrueClient auth) {
    final keeper = SupabaseSessionKeeper(auth: auth, clock: FakeClock(), database: database, logger: logger, store: store);
    addTearDown(keeper.dispose);
    return keeper;
  }

  /// Lets GoTrue's events reach the keeper, then its writes land.
  Future<void> settle(SupabaseSessionKeeper keeper) async {
    await pumpEventQueue();
    await keeper.idle;
  }

  Future<void> keep(Map<String, Object?> session, {bool withMarker = true}) async {
    store.values[SupabaseSessionKeeper.sessionKey] = jsonEncode(session);
    if (withMarker) {
      await database.into(database.settingsTable).insert(SettingsTableCompanion.insert(key: SupabaseSessionKeeper.keptMarkerKey, value: '1', updatedAt: 0));
    }
  }

  Future<bool> hasMarker() async => await (database.select(database.settingsTable)..where((t) => t.key.equals(SupabaseSessionKeeper.keptMarkerKey))).getSingleOrNull() != null;

  void expectNoTokenLogged() {
    final logged = logger.records.map((record) => '${record.message} ${record.fields} ${record.error}').join('\n');
    expect(logged, isNot(contains('header.')));
    expect(logged, isNot(contains('refresh-token')));
    expect(logged, isNot(contains(gotrueTestEmail)));
  }

  group('keeping', () {
    test('a sign-in keeps the session in the secure store, and marks the install', () async {
      final auth = gotrueClient(requests, (_) async => gotrueJson(200, gotrueSession()));
      final keeper = keeperFor(auth)..start();

      await auth.signInWithPassword(email: gotrueTestEmail, password: 'secret-1');
      await settle(keeper);

      final kept = jsonDecode(store.values[SupabaseSessionKeeper.sessionKey]!) as Map<String, Object?>;
      expect(kept['refresh_token'], 'refresh-token-1');
      expect((kept['user']! as Map<String, Object?>)['id'], gotrueTestUserId);
      expect(await hasMarker(), isTrue);
    });

    test('a sign-out drops the kept session', () async {
      final auth = gotrueClient(requests, (request) async => request.url.path.endsWith('/logout') ? http.Response('', 204) : gotrueJson(200, gotrueSession()));
      final keeper = keeperFor(auth)..start();
      await auth.signInWithPassword(email: gotrueTestEmail, password: 'secret-1');
      await settle(keeper);

      await auth.signOut();
      await settle(keeper);

      expect(store.values, isEmpty);
    });

    test('a store that cannot write is logged; the session still works in memory', () async {
      store.failing = true;
      final auth = gotrueClient(requests, (_) async => gotrueJson(200, gotrueSession()));
      final keeper = keeperFor(auth)..start();

      await auth.signInWithPassword(email: gotrueTestEmail, password: 'secret-1');
      await settle(keeper);

      expect(auth.currentSession, isNotNull);
      expect(logger.last.message, 'session keep failed');
      expect(logger.last.fields, {'error': 'PlatformException'});
    });

    test('a refresh token the server refuses signs out and drops the kept session', () async {
      await keep(gotrueSession(expiresAt: DateTime.now().subtract(const Duration(minutes: 5))));
      final auth = gotrueClient(requests, (_) async => gotrueError(400, 'refresh_token_not_found', 'Invalid Refresh Token: Refresh Token Not Found'));
      final keeper = keeperFor(auth)..start();
      await keeper.restore();

      await expectLater(auth.refreshSession(), throwsA(isA<AuthException>()));
      await settle(keeper);

      expect(auth.currentSession, isNull);
      expect(store.values, isEmpty);
    });

    test('a stream error, as a refresh that fails offline sends, keeps the kept copy and logs its type only', () async {
      await keep(gotrueSession());
      final auth = _ErroringGoTrueClient();
      final keeper = keeperFor(auth)..start();

      auth.events.addError(AuthRetryableFetchException(message: 'header.secret refresh-token-1'));
      await settle(keeper);

      expect(store.values, contains(SupabaseSessionKeeper.sessionKey));
      expect(logger.last.level, GPLogLevel.debug);
      expect(logger.last.fields, {'error': 'AuthRetryableFetchException'});
      expectNoTokenLogged();
    });
  });

  group('restoring', () {
    test('puts the kept session back with no network call', () async {
      await keep(gotrueSession());
      final auth = gotrueClient(requests, (_) async => fail('no request expected'));

      await keeperFor(auth).restore();

      expect(auth.currentSession?.user.id, gotrueTestUserId);
      expect(requests, isEmpty);
    });

    test('an expired session comes back too, offline: the refresh ticker renews it later', () async {
      await keep(gotrueSession(expiresAt: DateTime.now().subtract(const Duration(days: 2))));
      final auth = gotrueClient(requests, (_) async => fail('no request expected'));

      await keeperFor(auth).restore();

      expect(auth.currentSession?.isExpired, isTrue);
      expect(requests, isEmpty);
    });

    test('nothing kept restores nothing', () async {
      final auth = gotrueClient(requests, (_) async => fail('no request expected'));

      await keeperFor(auth).restore();

      expect(auth.currentSession, isNull);
      expect(logger.records, isEmpty);
    });

    test('a session without this install’s marker is from before a reinstall: dropped', () async {
      await keep(gotrueSession(), withMarker: false);
      final auth = gotrueClient(requests, (_) async => fail('no request expected'));

      await keeperFor(auth).restore();

      expect(auth.currentSession, isNull);
      expect(store.values, isEmpty);
      expect(logger.last.message, 'kept session from a previous install dropped');
    });

    test('an unreadable kept value is dropped and logged by type only', () async {
      await keep(gotrueSession());
      store.values[SupabaseSessionKeeper.sessionKey] = '{"access_token": "header.x", "refresh_token": "refresh-token-x"';
      final auth = gotrueClient(requests, (_) async => fail('no request expected'));

      await keeperFor(auth).restore();

      expect(auth.currentSession, isNull);
      expect(store.values, isEmpty);
      expect(logger.last.message, 'kept session unreadable, dropped');
      expectNoTokenLogged();
    });

    test('a store that cannot be read starts signed out, and does not throw', () async {
      store.failing = true;
      final auth = gotrueClient(requests, (_) async => fail('no request expected'));

      await keeperFor(auth).restore();

      expect(auth.currentSession, isNull);
      expect(logger.last.message, 'kept session read failed');
    });
  });

  test('the refresh ticker stops in the background and runs again on resume', () async {
    await keep(gotrueSession(expiresAt: DateTime.now().subtract(const Duration(minutes: 5))));
    final auth = gotrueClient(requests, (_) async => gotrueJson(200, gotrueSession(refreshToken: 'refresh-token-2')));
    addTearDown(auth.stopAutoRefresh);
    final keeper = keeperFor(auth)..start();
    await keeper.restore();
    final binding = TestWidgetsFlutterBinding.instance;

    const [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused].forEach(binding.handleAppLifecycleStateChanged);
    await pumpEventQueue();
    expect(requests, isEmpty);

    const [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed].forEach(binding.handleAppLifecycleStateChanged);
    await pumpEventQueue(times: 50);

    expect(requests.single.url.queryParameters, {'grant_type': 'refresh_token'});
    expect(auth.currentSession?.refreshToken, 'refresh-token-2');
  });
}

/// Its state stream is the test's, so a test can send the error a failed refresh sends without waiting out GoTrue's real-time retries.
final class _ErroringGoTrueClient extends GoTrueClient {
  _ErroringGoTrueClient() : super(url: gotrueBaseUrl, autoRefreshToken: false, flowType: AuthFlowType.implicit);

  final events = StreamController<AuthState>.broadcast();

  @override
  Stream<AuthState> get onAuthStateChange => events.stream;
}
