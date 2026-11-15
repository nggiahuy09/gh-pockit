import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/logging/app_logger.dart';
import 'package:ghpockit/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:ghpockit/features/auth/domain/entities/user_entity.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/recording_logger.dart';
import '../../../../helpers/results.dart';

// The response bodies and codes were read from a local GoTrue (`supabase start`, CLI 3.0.0) on 15/11/2026; the rate-limit code is GoTrue's
// own `ErrorCode.overRequestRateLimit`.
const _baseUrl = 'http://gotrue.test/auth/v1';
const _email = 'huy@example.com';
const _password = 'correct-horse-9';
const _userId = '0b6f1c2e-6a1d-4c58-9d6e-2f3a4b5c6d7e';

void main() {
  late List<http.Request> requests;
  late RecordingLogger logger;

  setUp(() {
    requests = [];
    logger = RecordingLogger(FakeClock());
  });

  /// The real client, so the tests pin GoTrue's parsing as well as the mapping on top of it.
  GoTrueClient client(Future<http.Response> Function(http.Request request) handler) => GoTrueClient(
    url: _baseUrl,
    autoRefreshToken: false,
    flowType: AuthFlowType.implicit,
    httpClient: MockClient((request) {
      requests.add(request);
      return handler(request);
    }),
  );

  SupabaseAuthRepository repository(GoTrueClient auth) => SupabaseAuthRepository(auth: auth, logger: logger);

  void expectNoSecretsLogged() {
    final logged = logger.records.map((record) => '${record.message} ${record.fields} ${record.error}').join('\n');
    expect(logged, isNot(contains(_email)));
    expect(logged, isNot(contains(_password)));
    expect(logged, isNot(contains('header.')));
    expect(logged, isNot(contains('refresh-token')));
  }

  group('signUp', () {
    test('returns the new user, signed in', () async {
      final auth = client((_) async => _json(200, _sessionBody()));

      final user = okValue(await repository(auth).signUp(email: _email, password: _password));

      expect(user, const UserEntity(id: _userId, email: _email));
      expect(auth.currentSession?.user.id, _userId);
      expect(requests.single.url.path, '/auth/v1/signup');
      expect(jsonDecode(requests.single.body), containsPair('email', _email));
      expect(logger.records, isEmpty);
    });

    test('sends no PKCE challenge: the implicit flow needs no verifier store', () async {
      final auth = client((_) async => _json(200, _sessionBody()));

      await repository(auth).signUp(email: _email, password: _password);

      expect(jsonDecode(requests.single.body), containsPair('code_challenge', null));
    });

    test('a taken email is a validation failure', () async {
      final auth = client((_) async => _error(422, 'user_already_exists', 'User already registered'));

      final result = await repository(auth).signUp(email: _email, password: _password);

      expect(result, const GPErr<UserEntity>(GPValidationFailure(GPValidationCode.authEmailTaken)));
      expect(auth.currentSession, isNull);
    });

    test('email_exists means the same thing', () async {
      final auth = client((_) async => _error(422, 'email_exists', 'Email address already exists'));

      final result = await repository(auth).signUp(email: _email, password: _password);

      expect(result, const GPErr<UserEntity>(GPValidationFailure(GPValidationCode.authEmailTaken)));
    });

    test("a password the server's policy refuses is weak", () async {
      final auth = client(
        (_) async => _json(422, {
          'code': 'weak_password',
          'message': 'Password should be at least 6 characters.',
          'weak_password': {
            'reasons': ['length'],
          },
        }),
      );

      final result = await repository(auth).signUp(email: _email, password: '123');

      expect(result, const GPErr<UserEntity>(GPValidationFailure(GPValidationCode.authPasswordWeak)));
    });

    test('an email the server refuses is invalid', () async {
      final auth = client((_) async => _error(400, 'email_address_invalid', 'Email address is invalid'));

      final result = await repository(auth).signUp(email: _email, password: _password);

      expect(result, const GPErr<UserEntity>(GPValidationFailure(GPValidationCode.authEmailInvalid)));
    });

    test('validation_failed names no field, so it stays unknown', () async {
      // GoTrue's body for a malformed email; an empty password gets the same code.
      final auth = client((_) async => _error(400, 'validation_failed', 'Unable to validate email address: invalid format'));

      final result = await repository(auth).signUp(email: 'not-an-email', password: _password);

      expect(result, const GPErr<UserEntity>(GPUnknownFailure()));
      expect(logger.last.fields, containsPair('code', 'validation_failed'));
    });

    test('no session in the answer, as with email confirmation on, is unknown', () async {
      final auth = client((_) async => _json(200, _userBody()));

      final result = await repository(auth).signUp(email: _email, password: _password);

      expect(result, const GPErr<UserEntity>(GPUnknownFailure()));
      expect(logger.last.message, 'sign up returned no session');
      expect(auth.currentSession, isNull);
    });

    test('a user without an email is unknown', () async {
      final auth = client((_) async => _json(200, _sessionBody(user: _userBody(email: null))));

      final result = await repository(auth).signUp(email: _email, password: _password);

      expect(result, const GPErr<UserEntity>(GPUnknownFailure()));
      expect(logger.last.fields, containsPair('user_id', _userId));
    });

    test('a 200 whose body GoTrue cannot parse is unknown, not a crash', () async {
      final auth = client((_) async => _json(200, {..._sessionBody(), 'user': 'not-an-object'}));

      final result = await repository(auth).signUp(email: _email, password: _password);

      expect(result, const GPErr<UserEntity>(GPUnknownFailure()));
      expect(logger.last.fields, containsPair('error', 'FormatException'));
    });
  });

  group('signIn', () {
    test('returns the user and holds the session', () async {
      final auth = client((_) async => _json(200, _sessionBody()));

      final user = okValue(await repository(auth).signIn(email: _email, password: _password));

      expect(user.id, _userId);
      expect(auth.currentSession?.accessToken, startsWith('header.'));
      expect(requests.single.url.path, '/auth/v1/token');
      expect(requests.single.url.queryParameters, {'grant_type': 'password'});
    });

    test('a wrong password and an unknown email are one failure', () async {
      final auth = client((_) async => _error(400, 'invalid_credentials', 'Invalid login credentials'));

      final result = await repository(auth).signIn(email: _email, password: 'wrong-pass-1');

      expect(result, const GPErr<UserEntity>(GPValidationFailure(GPValidationCode.authInvalidCredentials)));
      expect(logger.last.level, GPLogLevel.warn);
      expect(logger.last.fields, {'error': 'AuthApiException', 'code': 'invalid_credentials', 'status': '400', 'failure': 'GPValidationFailure'});
    });

    test('a rate limit is its own failure', () async {
      final auth = client((_) async => _error(429, 'over_request_rate_limit', 'Request rate limit reached'));

      final result = await repository(auth).signIn(email: _email, password: _password);

      expect(result, const GPErr<UserEntity>(GPRateLimitedFailure()));
    });

    test('a 429 with no code is still a rate limit', () async {
      final auth = client((_) async => _json(429, {'message': 'Too Many Requests'}));

      final result = await repository(auth).signIn(email: _email, password: _password);

      expect(result, const GPErr<UserEntity>(GPRateLimitedFailure()));
    });

    test('no route to the server is a network failure', () async {
      final auth = client((request) async => throw http.ClientException('Connection refused', request.url));

      final result = await repository(auth).signIn(email: _email, password: _password);

      expect(result, const GPErr<UserEntity>(GPNetworkFailure()));
      expect(auth.currentSession, isNull);
    });

    test('a 5xx is unknown, with its status logged', () async {
      final auth = client((_) async => http.Response('upstream down', 502));

      final result = await repository(auth).signIn(email: _email, password: _password);

      expect(result, const GPErr<UserEntity>(GPUnknownFailure()));
      expect(logger.last.fields, containsPair('status', '502'));
    });

    test('logs no email, password or token on any path', () async {
      final answers = [
        _json(200, _sessionBody()),
        _error(400, 'invalid_credentials', 'Invalid login credentials'),
        _json(200, {..._sessionBody(), 'user': 'not-an-object'}),
        http.Response('upstream down', 502),
      ];
      var call = 0;
      final auth = client((_) async => answers[call++]);

      for (var i = 0; i < answers.length; i++) {
        await repository(auth).signIn(email: _email, password: _password);
      }

      expect(logger.records, hasLength(3));
      expectNoSecretsLogged();
    });
  });

  group('signOut', () {
    test('revokes the session on the server and drops it here', () async {
      final auth = client((request) async => request.url.path.endsWith('/logout') ? http.Response('', 204) : _json(200, _sessionBody()));
      await repository(auth).signIn(email: _email, password: _password);

      final result = await repository(auth).signOut();

      expect(result, const GPOk<void>(null));
      expect(auth.currentSession, isNull);
      expect(requests.last.url.path, '/auth/v1/logout');
      expect(requests.last.headers['Authorization'], startsWith('Bearer header.'));
    });

    test('offline, still signs this device out and logs the failed revoke', () async {
      var online = true;
      final auth = client((request) async {
        if (!online) throw http.ClientException('Network is unreachable', request.url);
        return _json(200, _sessionBody());
      });
      await repository(auth).signIn(email: _email, password: _password);
      online = false;

      final result = await repository(auth).signOut();

      expect(result, const GPOk<void>(null));
      expect(auth.currentSession, isNull);
      expect(logger.last.message, 'sign out revoke failed');
      expect(logger.last.fields, containsPair('error', 'AuthRetryableFetchException'));
      expectNoSecretsLogged();
    });

    test('a session the server already ended is not an error', () async {
      final auth = client(
        (request) async =>
            request.url.path.endsWith('/logout') ? _error(403, 'session_not_found', 'Session from session_id claim in JWT does not exist') : _json(200, _sessionBody()),
      );
      await repository(auth).signIn(email: _email, password: _password);

      final result = await repository(auth).signOut();

      expect(result, const GPOk<void>(null));
      expect(logger.records, isEmpty);
    });

    test('with no session, calls nothing', () async {
      final auth = client((_) async => fail('no request expected'));

      final result = await repository(auth).signOut();

      expect(result, const GPOk<void>(null));
      expect(requests, isEmpty);
    });
  });
}

http.Response _json(int status, Map<String, Object?> body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json', 'x-supabase-api-version': '2024-01-01'});

http.Response _error(int status, String code, String message) => _json(status, {'code': code, 'message': message});

Map<String, Object?> _userBody({String? email = _email}) => {
  'id': _userId,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': email,
  'app_metadata': {
    'provider': 'email',
    'providers': ['email'],
  },
  'user_metadata': {'email_verified': true},
  'created_at': '2026-11-15T09:00:00Z',
  'updated_at': '2026-11-15T09:00:00Z',
  'is_anonymous': false,
};

Map<String, Object?> _sessionBody({Map<String, Object?>? user}) => {
  'access_token': _fakeJwt(),
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at': 1794733200,
  'refresh_token': 'refresh-token-1',
  'user': user ?? _userBody(),
};

/// GoTrue decodes the payload for `exp`; the signature is never checked client-side. Starts with `header.` so a leak is easy to search for.
String _fakeJwt() => 'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': _userId, 'exp': 1794733200}))).replaceAll('=', '')}.signature';
