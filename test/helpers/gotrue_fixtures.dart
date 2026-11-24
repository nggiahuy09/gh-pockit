import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';

// Shapes read from a local GoTrue (`supabase start`, CLI 3.0.0) on 15/11/2026.
const gotrueBaseUrl = 'http://gotrue.test/auth/v1';
const gotrueTestEmail = 'huy@example.com';
const gotrueTestUserId = '0b6f1c2e-6a1d-4c58-9d6e-2f3a4b5c6d7e';

/// The real client over [handler], so a test pins GoTrue's parsing too. Every request lands in [requests].
GoTrueClient gotrueClient(List<http.Request> requests, Future<http.Response> Function(http.Request request) handler) => GoTrueClient(
  url: gotrueBaseUrl,
  autoRefreshToken: false,
  flowType: AuthFlowType.implicit,
  httpClient: MockClient((request) {
    requests.add(request);
    return handler(request);
  }),
);

http.Response gotrueJson(int status, Map<String, Object?> body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json', 'x-supabase-api-version': '2024-01-01'});

http.Response gotrueError(int status, String code, String message) => gotrueJson(status, {'code': code, 'message': message});

Map<String, Object?> gotrueUser({String? email = gotrueTestEmail}) => {
  'id': gotrueTestUserId,
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

/// GoTrue checks expiry against the real clock, so [expiresAt] defaults to an hour from now.
Map<String, Object?> gotrueSession({Map<String, Object?>? user, DateTime? expiresAt, String refreshToken = 'refresh-token-1'}) {
  final exp = (expiresAt ?? DateTime.now().add(const Duration(hours: 1))).millisecondsSinceEpoch ~/ 1000;
  return {
    'access_token': fakeJwt(exp),
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': exp,
    'refresh_token': refreshToken,
    'user': user ?? gotrueUser(),
  };
}

/// GoTrue decodes the payload for `exp`; the signature is never checked client-side. Starts with `header.` so a leak is easy to search for.
String fakeJwt(int exp) => 'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': gotrueTestUserId, 'exp': exp}))).replaceAll('=', '')}.signature';
