import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/sync/sync_entity_type.dart';
import 'package:ghpockit/core/sync/sync_mutation.dart';
import 'package:ghpockit/core/sync/sync_mutation_mapper.dart';
import 'package:ghpockit/core/sync/sync_mutation_status.dart';
import 'package:ghpockit/core/sync/sync_operation.dart';

const _queuedAt = 1795000000000;

void main() {
  late GPAppDatabase db;

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<SyncMutationRow> roundTrip(GPSyncMutation mutation) async {
    await db.into(db.syncMutationsTable).insert(mutation.toInsert());
    return (db.select(db.syncMutationsTable)..where((t) => t.id.equals(mutation.id))).getSingle();
  }

  test('a mutation written and read back through a real table is the same mutation', () async {
    final retried = GPSyncMutation(
      id: 'm-1',
      entityType: GPSyncEntityType.transaction,
      entityId: 'tx-1',
      operation: GPSyncOperation.update,
      payload: _payload,
      idempotencyKey: 'k-1',
      createdAt: DateTime.fromMillisecondsSinceEpoch(_queuedAt, isUtc: true),
      attemptCount: 3,
      nextAttemptAt: DateTime.fromMillisecondsSinceEpoch(_queuedAt + 8000, isUtc: true),
      status: GPSyncMutationStatus.pending,
      lastErrorCode: 'network',
    );

    final mapped = (await roundTrip(retried)).toDomain();

    expect(mapped, isA<GPMappedSyncMutation>().having((m) => m.mutation, 'mutation', retried));
  });

  test('stores epoch millis and the storage values, not Dart names', () async {
    final row = await roundTrip(
      GPSyncMutation.enqueued(
        id: 'm-1',
        entityType: GPSyncEntityType.account,
        entityId: 'acc-1',
        operation: GPSyncOperation.create,
        payload: const {'id': 'acc-1'},
        idempotencyKey: 'k-1',
        createdAt: DateTime.fromMillisecondsSinceEpoch(_queuedAt, isUtc: true),
      ),
    );

    expect(row.entityType, 'account');
    expect(row.operation, 'create');
    expect(row.status, 'pending');
    expect(row.createdAt, _queuedAt);
    expect(row.nextAttemptAt, _queuedAt);
    expect(row.payloadJson, '{"id":"acc-1"}');
    expect(row.lastErrorCode, isNull);
  });

  test('the payload survives as JSON: past 32 bits, null, booleans, Vietnamese text, quotes and line breaks', () async {
    final row = await roundTrip(_enqueued(_payload));

    expect((row.toDomain() as GPMappedSyncMutation).mutation.payload, _payload);
  });

  group('refuses a row it cannot read, naming the check and not the value', () {
    final cases = {
      'an entity type this build does not know': (_row(entityType: 'budget'), GPSyncMutationMapperReason.unknownEntityType),
      'an operation this build does not know': (_row(operation: 'upsert'), GPSyncMutationMapperReason.unknownOperation),
      'a status this build does not know': (_row(status: 'completed'), GPSyncMutationMapperReason.unknownStatus),
      'a payload that is not JSON': (_row(payloadJson: '{"id":'), GPSyncMutationMapperReason.malformedPayload),
      'a payload that is JSON but not an object': (_row(payloadJson: '["tx-1"]'), GPSyncMutationMapperReason.malformedPayload),
      'a payload that is JSON null': (_row(payloadJson: 'null'), GPSyncMutationMapperReason.malformedPayload),
    };

    for (final MapEntry(key: name, value: (row, reason)) in cases.entries) {
      test(name, () async {
        await db.into(db.syncMutationsTable).insert(row);

        final mapped = (await db.select(db.syncMutationsTable).getSingle()).toDomain();

        expect(mapped, isA<GPUnmappableSyncMutationRow>().having((m) => m.reason, 'reason', reason).having((m) => m.failure, 'failure', const GPDatabaseFailure()));
      });
    }
  });
}

const _payload = <String, Object?>{
  'id': 'tx-1',
  'owner_id': '0193f1a2-0000-7000-8000-000000000001',
  'amount_minor': 1000000000000,
  'category_id': null,
  'is_archived': false,
  'note': 'Phở bò "đặc biệt"\nquán cô Ba',
  'version': 3,
};

GPSyncMutation _enqueued(Map<String, Object?> payload) => GPSyncMutation.enqueued(
  id: 'm-1',
  entityType: GPSyncEntityType.transaction,
  entityId: 'tx-1',
  operation: GPSyncOperation.create,
  payload: payload,
  idempotencyKey: 'k-1',
  createdAt: DateTime.fromMillisecondsSinceEpoch(_queuedAt, isUtc: true),
);

SyncMutationsTableCompanion _row({String entityType = 'transaction', String operation = 'create', String status = 'pending', String payloadJson = '{"id":"tx-1"}'}) =>
    SyncMutationsTableCompanion.insert(
      id: 'm-1',
      entityType: entityType,
      entityId: 'tx-1',
      operation: operation,
      payloadJson: payloadJson,
      idempotencyKey: 'k-1',
      createdAt: _queuedAt,
      attemptCount: 0,
      nextAttemptAt: _queuedAt,
      status: status,
      lastErrorCode: const Value(null),
    );
