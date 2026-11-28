import 'package:ghpockit/core/sync/sync_entity_type.dart';
import 'package:ghpockit/core/sync/sync_mutation.dart';
import 'package:ghpockit/core/sync/sync_operation.dart';

final _queuedAt = DateTime.utc(2026, 12, 7, 3);

/// A transaction update as the queue holds it, its key derived from [id].
GPSyncMutation queuedMutation(String id, {Map<String, Object?>? payload}) => GPSyncMutation.enqueued(
  id: id,
  entityType: GPSyncEntityType.transaction,
  entityId: (payload?['id'] as String?) ?? 'tx-$id',
  operation: GPSyncOperation.update,
  payload: payload ?? {'id': 'tx-$id', 'version': 1},
  idempotencyKey: 'key-$id',
  createdAt: _queuedAt,
);

/// [queuedMutation] as `markSending` returns it.
GPSyncMutation sendableMutation(String id, {Map<String, Object?>? payload}) => queuedMutation(id, payload: payload).sending();
