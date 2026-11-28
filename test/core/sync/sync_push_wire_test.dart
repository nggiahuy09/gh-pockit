import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/sync/sync_push_result.dart';
import 'package:ghpockit/core/sync/sync_push_wire.dart';

import '../../helpers/sync_mutations.dart';

const _stampedAtMs = 1796612400123;

void main() {
  group('encodePushRequest', () {
    test('sends each mutation with its key and its payload as queued, and no base version or owner beside the payload', () {
      final mutation = sendableMutation('m-1', payload: {'id': 'tx-1', 'owner_id': 'u-1', 'version': 3, 'amount_minor': 125000, 'note': null});

      final request = encodePushRequest([mutation]);

      expect(request, [
        {
          'mutation_id': 'm-1',
          'entity_type': 'transaction',
          'entity_id': 'tx-1',
          'operation': 'update',
          'idempotency_key': 'key-m-1',
          'payload': {'id': 'tx-1', 'owner_id': 'u-1', 'version': 3, 'amount_minor': 125000, 'note': null},
        },
      ]);
      // What the RPC body becomes: jsonEncode must take it as is.
      expect(() => jsonEncode(request), returnsNormally);
    });

    test('keeps the batch order, parents first as the queue handed them out', () {
      final request = encodePushRequest([sendableMutation('m-1'), sendableMutation('m-2'), sendableMutation('m-3')]);

      expect(request.map((m) => m['mutation_id']), ['m-1', 'm-2', 'm-3']);
    });

    test('refuses a mutation that markSending did not return', () {
      expect(() => encodePushRequest([queuedMutation('m-1')]), throwsArgumentError);
    });

    test('refuses a batch holding one mutation twice', () {
      expect(() => encodePushRequest([sendableMutation('m-1'), sendableMutation('m-1')]), throwsArgumentError);
    });
  });

  group('decodePushResponse', () {
    final sent = [sendableMutation('m-1'), sendableMutation('m-2'), sendableMutation('m-3')];

    test('reads applied, conflict and rejected, in the order sent whatever order they arrive in', () {
      final results = decodePushResponse([
        {'mutation_id': 'm-3', 'status': 'rejected', 'code': 'transactions_destination_iff_transfer'},
        {
          'mutation_id': 'm-1',
          'status': 'applied',
          'server_version': 4,
          'server_updated_at': _stampedAtMs,
        },
        {
          'mutation_id': 'm-2',
          'status': 'conflict',
          'remote': {'id': 'tx-2', 'version': 7, 'amount_minor': 99000},
        },
      ], sent);

      expect(results, [
        GPSyncPushApplied(mutationId: 'm-1', serverVersion: 4, serverUpdatedAt: DateTime.fromMillisecondsSinceEpoch(_stampedAtMs, isUtc: true)),
        GPSyncPushConflict(mutationId: 'm-2', remote: const {'id': 'tx-2', 'version': 7, 'amount_minor': 99000}),
        const GPSyncPushRejected(mutationId: 'm-3', code: 'transactions_destination_iff_transfer'),
      ]);
      expect((results[0] as GPSyncPushApplied).serverUpdatedAt.isUtc, isTrue);
      expect((results[1] as GPSyncPushConflict).serverVersion, 7);
    });

    test('reads the body jsonDecode gives, which types its maps and lists as dynamic', () {
      final body = jsonDecode(
        jsonEncode([
          {'mutation_id': 'm-1', 'status': 'applied', 'server_version': 1, 'server_updated_at': _stampedAtMs},
        ]),
      );

      expect(decodePushResponse(body, [sendableMutation('m-1')]).single, isA<GPSyncPushApplied>());
    });

    final malformed = <String, (Object?, GPPushResponseProblem)>{
      'not a list': (<String, Object?>{'results': <Object?>[]}, GPPushResponseProblem.notAList),
      'a null body': (null, GPPushResponseProblem.notAList),
      'an item that is not an object': (['m-1'], GPPushResponseProblem.notAnObject),
      'an unknown status': (
        [
          {'mutation_id': 'm-1', 'status': 'upserted'},
        ],
        GPPushResponseProblem.unknownStatus,
      ),
      'applied without a server version': (
        [
          {'mutation_id': 'm-1', 'status': 'applied', 'server_updated_at': _stampedAtMs},
        ],
        GPPushResponseProblem.badField,
      ),
      'applied with an ISO time instead of epoch millis': (
        [
          {'mutation_id': 'm-1', 'status': 'applied', 'server_version': 2, 'server_updated_at': '2026-12-07T03:00:00Z'},
        ],
        GPPushResponseProblem.badField,
      ),
      'a conflict without the server row': (
        [
          {'mutation_id': 'm-1', 'status': 'conflict'},
        ],
        GPPushResponseProblem.badField,
      ),
      'a conflict whose row is nested': (
        [
          {
            'mutation_id': 'm-1',
            'status': 'conflict',
            'remote': {
              'id': 'tx-1',
              'meta': {'a': 1},
            },
          },
        ],
        GPPushResponseProblem.badField,
      ),
      'a rejection with an empty code': (
        [
          {'mutation_id': 'm-1', 'status': 'rejected', 'code': ''},
        ],
        GPPushResponseProblem.badField,
      ),
      'an answer for a mutation not sent': (
        [
          {'mutation_id': 'm-9', 'status': 'rejected', 'code': 'not_found'},
        ],
        GPPushResponseProblem.unknownMutation,
      ),
      'two answers for one mutation': (
        [
          {'mutation_id': 'm-1', 'status': 'rejected', 'code': 'not_found'},
          {'mutation_id': 'm-1', 'status': 'rejected', 'code': 'not_found'},
        ],
        GPPushResponseProblem.duplicateResult,
      ),
      'no answer for a mutation sent': (<Object?>[], GPPushResponseProblem.missingResult),
    };

    for (final MapEntry(key: name, value: (body, problem)) in malformed.entries) {
      test('throws on $name, naming the check and never the body', () {
        expect(
          () => decodePushResponse(body, [sendableMutation('m-1')]),
          throwsA(isA<GPMalformedPushResponse>().having((e) => e.problem, 'problem', problem).having((e) => e.toString(), 'toString', isNot(contains('tx-1')))),
        );
      });
    }
  });

  group('results log', () {
    test('ids, the server version and the code, never the remote row', () {
      final conflict = GPSyncPushConflict(mutationId: 'm-2', remote: const {'id': 'tx-2', 'version': 7, 'amount_minor': 99000, 'note': 'rent'});

      expect(conflict.toLog(), {'mutation_id': 'm-2', 'result': 'conflict', 'server_version': 7});
      expect(const GPSyncPushRejected(mutationId: 'm-3', code: 'not_found').toLog(), {'mutation_id': 'm-3', 'result': 'rejected', 'code': 'not_found'});
    });
  });
}
