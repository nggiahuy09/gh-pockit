import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/sync/supabase_sync_remote_data_source.dart';
import 'package:ghpockit/core/sync/sync_push_result.dart';
import 'package:ghpockit/core/sync/sync_push_wire.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';

import '../../helpers/sync_mutations.dart';

const _restUrl = 'http://127.0.0.1:54321/rest/v1';

void main() {
  late List<http.Request> requests;

  GPSupabaseSyncRemoteDataSource dataSource(Future<http.Response> Function(http.Request request) handler, {Duration timeout = const Duration(seconds: 30)}) {
    final client = MockClient((request) {
      requests.add(request);
      return handler(request);
    });
    return GPSupabaseSyncRemoteDataSource(
      rest: PostgrestClient(_restUrl, httpClient: client),
      requestTimeout: timeout,
    );
  }

  // Postgrest reads the response's request to parse it.
  http.Response json(http.Request request, Object? body, {int status = 200}) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'}, request: request);

  setUp(() => requests = []);

  test('posts the batch to the push function as its one argument and returns its results', () async {
    final remote = dataSource(
      (request) async => json(request, [
        {'mutation_id': 'm-1', 'status': 'applied', 'server_version': 1, 'server_updated_at': 1796612400123},
      ]),
    );
    final mutation = sendableMutation('m-1');

    final results = await remote.push([mutation]);

    expect(results.single, isA<GPSyncPushApplied>().having((r) => r.serverVersion, 'serverVersion', 1));
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.toString(), '$_restUrl/rpc/push_mutations');
    expect(jsonDecode(request.body), {
      pushMutationsParam: encodePushRequest([mutation]),
    });
  });

  test('an empty batch sends nothing', () async {
    final remote = dataSource((_) async => fail('no request expected'));

    expect(await remote.push(const []), isEmpty);
    expect(requests, isEmpty);
  });

  test('a 503 is thrown once, never resent behind the engine', () async {
    final remote = dataSource((request) async => json(request, {'message': 'unavailable', 'code': 'PGRST000'}, status: 503));

    await expectLater(remote.push([sendableMutation('m-1')]), throwsA(isA<PostgrestException>()));
    expect(requests, hasLength(1));
  });

  test('a database error reaches the caller as the transport threw it, for the engine to classify', () async {
    final remote = dataSource((request) async => json(request, {'message': 'permission denied', 'code': '42501'}, status: 401));

    await expectLater(remote.push([sendableMutation('m-1')]), throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')));
  });

  test('a 200 that does not answer every mutation is refused, not half applied', () async {
    final remote = dataSource(
      (request) async => json(request, [
        {'mutation_id': 'm-1', 'status': 'applied', 'server_version': 2, 'server_updated_at': 1796612400123},
      ]),
    );

    await expectLater(
      remote.push([sendableMutation('m-1'), sendableMutation('m-2')]),
      throwsA(isA<GPMalformedPushResponse>().having((e) => e.problem, 'problem', GPPushResponseProblem.missingResult)),
    );
  });

  test('a push that hangs past the timeout is aborted and throws instead of holding the sync', () async {
    final client = _HangingClient();
    final remote = GPSupabaseSyncRemoteDataSource(
      rest: PostgrestClient(_restUrl, httpClient: client),
      requestTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(remote.push([sendableMutation('m-1')]), throwsA(isA<TimeoutException>()));
    expect(client.aborted, isTrue);
  });
}

/// Answers nothing until postgrest aborts the request, as a real client does with a stalled socket.
final class _HangingClient extends http.BaseClient {
  bool aborted = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await (request as http.Abortable).abortTrigger;
    aborted = true;
    throw http.RequestAbortedException(request.url);
  }
}
