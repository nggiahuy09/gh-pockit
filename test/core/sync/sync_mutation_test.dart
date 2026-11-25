import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/sync/sync_entity_type.dart';
import 'package:ghpockit/core/sync/sync_mutation.dart';
import 'package:ghpockit/core/sync/sync_mutation_status.dart';
import 'package:ghpockit/core/sync/sync_operation.dart';

final _queuedAt = DateTime.utc(2026, 11, 25, 3);

void main() {
  group('enqueued', () {
    test('is pending, never attempted, and ready the moment it is queued', () {
      final mutation = _enqueued();

      expect(mutation.status, GPSyncMutationStatus.pending);
      expect(mutation.attemptCount, 0);
      expect(mutation.nextAttemptAt, _queuedAt);
      expect(mutation.lastErrorCode, isNull);
      expect(mutation.isUnattempted, isTrue);
    });

    test('holds its times in UTC whatever zone they were given in', () {
      final local = DateTime.fromMillisecondsSinceEpoch(_queuedAt.millisecondsSinceEpoch);

      final mutation = _enqueued(createdAt: local);

      expect(mutation.createdAt.isUtc, isTrue);
      expect(mutation.nextAttemptAt.isUtc, isTrue);
      expect(mutation.createdAt, _queuedAt);
    });

    test('keeps the payload as it was queued, whatever happens to the map it came from', () {
      final source = <String, Object?>{'id': 'tx-1', 'amount_minor': 125000};

      final mutation = _enqueued(payload: source);
      source['amount_minor'] = 1;

      expect(mutation.payload['amount_minor'], 125000);
      expect(() => mutation.payload['amount_minor'] = 2, throwsUnsupportedError);
    });

    test('drops what finer than a millisecond the clock gave, so the mutation survives a write and a read unchanged', () {
      final fine = DateTime.utc(2026, 11, 25, 3, 0, 0, 123, 456);

      final mutation = _enqueued(createdAt: fine);

      expect(mutation.createdAt, DateTime.utc(2026, 11, 25, 3, 0, 0, 123));
      expect(mutation.nextAttemptAt, DateTime.utc(2026, 11, 25, 3, 0, 0, 123));
    });

    group('refuses a payload that is not one flat row of JSON scalars, naming the column and never the value', () {
      final cases = <String, Object?>{
        'a time object': DateTime.utc(2026),
        'a double': 1250.5,
        'a nested list': ['food'],
        'a nested map': {'minor': 125000},
        'an enum': GPSyncOperation.create,
      };

      for (final MapEntry(key: name, value: value) in cases.entries) {
        test(name, () {
          expect(
            () => _enqueued(payload: {'id': 'tx-1', 'amount_minor': value}),
            throwsA(isA<ArgumentError>().having((e) => e.message, 'message', allOf(contains('"amount_minor"'), isNot(contains(value.toString()))))),
          );
        });
      }
    });

    test('takes strings, integers past 32 bits, booleans and nulls', () {
      expect(_enqueued(payload: {'id': 'tx-1', 'amount_minor': 1000000000000, 'is_archived': false, 'note': null}).payload, hasLength(4));
    });
  });

  group('isUnattempted', () {
    test('is false once a push has been tried, or the mutation left pending', () {
      expect(_with(attemptCount: 1).isUnattempted, isFalse);
      expect(_with(status: GPSyncMutationStatus.processing).isUnattempted, isFalse);
      expect(_with(status: GPSyncMutationStatus.conflict).isUnattempted, isFalse);
      expect(_with(status: GPSyncMutationStatus.failed).isUnattempted, isFalse);
    });

    test('stays false for a mutation orphaned mid-push and put back to pending', () {
      final sent = _enqueued().sending();

      // What a kill after the request left, then the reset at launch, leave behind: pending again, the attempt kept.
      final orphan = _with(attemptCount: sent.attemptCount);

      expect(orphan.isUnattempted, isFalse);
      expect(() => orphan.coalescedWith(operation: GPSyncOperation.update, payload: const {'id': 'tx-1'}), throwsStateError);
    });
  });

  group('sending', () {
    test('puts the mutation in flight and counts the attempt before any answer', () {
      final queued = _enqueued();

      final sent = queued.sending();

      expect(sent.status, GPSyncMutationStatus.processing);
      expect(sent.attemptCount, 1);
      expect(
        [sent.id, sent.idempotencyKey, sent.payload, sent.createdAt, sent.nextAttemptAt],
        [queued.id, queued.idempotencyKey, queued.payload, queued.createdAt, queued.nextAttemptAt],
      );
    });

    test('counts on from earlier attempts and keeps the last error code', () {
      final sent = _with(attemptCount: 3, lastErrorCode: 'network').sending();

      expect(sent.attemptCount, 4);
      expect(sent.lastErrorCode, 'network');
    });

    test('refuses a mutation that is not pending', () {
      for (final status in [GPSyncMutationStatus.processing, GPSyncMutationStatus.conflict, GPSyncMutationStatus.failed]) {
        expect(() => _with(status: status).sending(), throwsStateError, reason: status.name);
      }
    });
  });

  group('coalescedWith', () {
    test('carries the later payload under the same id, key and place in the queue', () {
      final first = _enqueued(operation: GPSyncOperation.update, payload: {'id': 'tx-1', 'note': 'Phở'});

      final folded = first.coalescedWith(operation: GPSyncOperation.update, payload: {'id': 'tx-1', 'note': 'Phở bò'});

      expect(folded.payload, {'id': 'tx-1', 'note': 'Phở bò'});
      expect(folded.id, first.id);
      expect(folded.idempotencyKey, first.idempotencyKey);
      expect(folded.createdAt, first.createdAt);
      expect(folded.nextAttemptAt, first.nextAttemptAt);
      expect(folded.isUnattempted, isTrue);
    });

    test('folds the operation by the rule, so a row the server never had stays a create', () {
      final created = _enqueued();

      expect(created.coalescedWith(operation: GPSyncOperation.delete, payload: const {}).operation, GPSyncOperation.create);
      expect(_enqueued(operation: GPSyncOperation.delete).coalescedWith(operation: GPSyncOperation.update, payload: const {}).operation, GPSyncOperation.update);
    });

    test('refuses a mutation that has been sent: the server may hold its key for the old payload', () {
      for (final sent in [_with(attemptCount: 1), _with(status: GPSyncMutationStatus.processing), _with(status: GPSyncMutationStatus.failed)]) {
        expect(() => sent.coalescedWith(operation: GPSyncOperation.update, payload: const {}), throwsStateError);
      }
    });
  });

  group('toLog', () {
    test('names the mutation and its state, never the payload or the key', () {
      final log = _with(attemptCount: 3, lastErrorCode: 'network').toLog();

      expect(log, {
        'mutation_id': 'm-1',
        'entity_type': 'transaction',
        'entity_id': 'tx-1',
        'operation': 'create',
        'status': 'pending',
        'attempt_count': 3,
        'last_error_code': 'network',
      });
      expect(log.values, isNot(contains('k-1')));
    });

    test('leaves the error code out until there is one', () {
      expect(_enqueued().toLog().containsKey('last_error_code'), isFalse);
    });
  });

  test('two mutations with the same fields are equal, the payload compared by content', () {
    expect(_enqueued(payload: {'id': 'tx-1', 'amount_minor': 125000}), _enqueued(payload: {'amount_minor': 125000, 'id': 'tx-1'}));
    expect(_enqueued(payload: {'id': 'tx-1'}), isNot(_enqueued(payload: {'id': 'tx-2'})));
  });
}

GPSyncMutation _enqueued({GPSyncOperation operation = GPSyncOperation.create, Map<String, Object?> payload = const {'id': 'tx-1'}, DateTime? createdAt}) => GPSyncMutation.enqueued(
  id: 'm-1',
  entityType: GPSyncEntityType.transaction,
  entityId: 'tx-1',
  operation: operation,
  payload: payload,
  idempotencyKey: 'k-1',
  createdAt: createdAt ?? _queuedAt,
);

GPSyncMutation _with({int attemptCount = 0, GPSyncMutationStatus status = GPSyncMutationStatus.pending, String? lastErrorCode}) => GPSyncMutation(
  id: 'm-1',
  entityType: GPSyncEntityType.transaction,
  entityId: 'tx-1',
  operation: GPSyncOperation.create,
  payload: const {'id': 'tx-1'},
  idempotencyKey: 'k-1',
  createdAt: _queuedAt,
  attemptCount: attemptCount,
  nextAttemptAt: _queuedAt,
  status: status,
  lastErrorCode: lastErrorCode,
);
