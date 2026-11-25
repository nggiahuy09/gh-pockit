import 'package:drift/drift.dart';

import '../database/database.dart';
import '../logging/app_logger.dart';
import '../utils/clock.dart';
import '../utils/uuid_generator.dart';
import 'sync_entity_type.dart';
import 'sync_mutation.dart';
import 'sync_mutation_mapper.dart';
import 'sync_mutation_status.dart';
import 'sync_operation.dart';
import 'sync_queue_repository.dart';

final class GPDriftSyncQueueRepository implements GPSyncQueueRepository {
  GPDriftSyncQueueRepository({required GPAppDatabase database, required GPClock clock, required GPUuidGenerator uuidGenerator, required GPAppLogger logger})
    : _database = database,
      _clock = clock,
      _uuidGenerator = uuidGenerator,
      _logger = logger;

  final GPAppDatabase _database;
  final GPClock _clock;
  final GPUuidGenerator _uuidGenerator;
  final GPAppLogger _logger;

  /// Repeats the partial index's WHERE with literals, or SQLite cannot prove it applies and scans instead.
  static const unattemptedSql = "SELECT * FROM sync_mutations WHERE entity_type = ?1 AND entity_id = ?2 AND status = 'pending' AND attempt_count = 0";

  /// `created_at, id` keeps the order the writes happened in, so a parent created before its child is pushed before it.
  static const readySql = "SELECT * FROM sync_mutations WHERE status = 'pending' AND next_attempt_at <= ?1 ORDER BY created_at, id LIMIT ?2";

  static const countUnsyncedEntitiesSql = 'SELECT COUNT(*) AS entities FROM (SELECT DISTINCT entity_type, entity_id FROM sync_mutations)';

  /// Stored on a row this build cannot read, so Diagnostics can tell it from a failure the server reported.
  static const unreadableRowCode = 'unreadable_row';

  static const defaultReadyLimit = 50;

  $SyncMutationsTableTable get _table => _database.syncMutationsTable;

  @override
  Future<GPSyncMutation> enqueue({required GPSyncEntityType entityType, required String entityId, required GPSyncOperation operation, required Map<String, Object?> payload}) {
    // Joins the caller's transaction as a savepoint, so the lookup and the write see the same queue.
    return _database.transaction(() async {
      final unsent = await _database
          .customSelect(unattemptedSql, variables: [Variable.withString(entityType.storageValue), Variable.withString(entityId)], readsFrom: {_table})
          .getSingleOrNull();

      if (unsent != null) {
        switch (_table.map(unsent.data).toDomain()) {
          case GPMappedSyncMutation(:final mutation):
            final folded = mutation.coalescedWith(operation: operation, payload: payload);
            await (_database.update(_table)..where((t) => t.id.equals(folded.id))).write(folded.toFoldPatch());
            return folded;
          case GPUnmappableSyncMutationRow(:final reason):
            // Nothing can fold into a row it cannot read; marking it failed moves it out of the partial index for the new one.
            await _markUnreadable(unsent.read<String>('id'), reason);
        }
      }

      final mutation = GPSyncMutation.enqueued(
        id: _uuidGenerator.v7(),
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: payload,
        idempotencyKey: _uuidGenerator.v4(),
        createdAt: _clock.nowUtc(),
      );
      await _database.into(_table).insert(mutation.toInsert());
      return mutation;
    });
  }

  @override
  Future<List<GPSyncMutation>> getReadyMutations({int limit = defaultReadyLimit}) async {
    final rows = await _database
        .customSelect(readySql, variables: [Variable.withInt(_clock.nowEpochMillis()), Variable.withInt(limit)], readsFrom: {_table})
        .map((row) => _table.map(row.data))
        .get();

    final ready = <GPSyncMutation>[];
    for (final row in rows) {
      switch (row.toDomain()) {
        case GPMappedSyncMutation(:final mutation):
          ready.add(mutation);
        case GPUnmappableSyncMutationRow(:final reason):
          await _markUnreadable(row.id, reason);
      }
    }
    return ready;
  }

  @override
  Future<GPSyncMutation?> markSending(String id) {
    return _database.transaction(() async {
      final row = await (_database.select(_table)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) return null;

      switch (row.toDomain()) {
        case GPUnmappableSyncMutationRow(:final reason):
          await _markUnreadable(id, reason);
          return null;
        case GPMappedSyncMutation(:final mutation):
          if (mutation.status != GPSyncMutationStatus.pending) return null;
          final sent = mutation.sending();
          await (_database.update(_table)..where((t) => t.id.equals(id))).write(sent.toStatePatch());
          return sent;
      }
    });
  }

  @override
  Future<void> complete(String id) => (_database.delete(_table)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> scheduleRetry(String id, {required DateTime nextAttemptAt, required String errorCode}) => _settleInFlight(
    id,
    SyncMutationsTableCompanion(
      status: Value(GPSyncMutationStatus.pending.storageValue),
      nextAttemptAt: Value(nextAttemptAt.millisecondsSinceEpoch),
      lastErrorCode: Value(errorCode),
    ),
  );

  @override
  Future<void> markConflict(String id, {required String errorCode}) =>
      _settleInFlight(id, SyncMutationsTableCompanion(status: Value(GPSyncMutationStatus.conflict.storageValue), lastErrorCode: Value(errorCode)));

  @override
  Future<void> markFailed(String id, {required String errorCode}) =>
      _settleInFlight(id, SyncMutationsTableCompanion(status: Value(GPSyncMutationStatus.failed.storageValue), lastErrorCode: Value(errorCode)));

  @override
  Future<int> resetOrphans() async {
    final reset = await (_database.update(_table)..where((t) => t.status.equals(GPSyncMutationStatus.processing.storageValue))).write(
      SyncMutationsTableCompanion(status: Value(GPSyncMutationStatus.pending.storageValue)),
    );
    if (reset > 0) _logger.info('orphaned sync mutations reset to pending', fields: {'count': reset});
    return reset;
  }

  @override
  Future<int> countUnsyncedEntities() async {
    final row = await _database.customSelect(countUnsyncedEntitiesSql, readsFrom: {_table}).getSingle();
    return row.read<int>('entities');
  }

  /// Only a mutation in flight has an answer to settle; any other is left alone.
  Future<void> _settleInFlight(String id, SyncMutationsTableCompanion patch) =>
      (_database.update(_table)..where((t) => t.id.equals(id) & t.status.equals(GPSyncMutationStatus.processing.storageValue))).write(patch);

  Future<void> _markUnreadable(String id, GPSyncMutationMapperReason reason) async {
    await (_database.update(_table)..where((t) => t.id.equals(id))).write(
      SyncMutationsTableCompanion(status: Value(GPSyncMutationStatus.failed.storageValue), lastErrorCode: const Value(unreadableRowCode)),
    );
    _logger.warn('unreadable sync mutation marked failed', fields: {'mutation_id': id, 'reason': reason.name});
  }
}
