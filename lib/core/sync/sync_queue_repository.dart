import 'sync_entity_type.dart';
import 'sync_mutation.dart';
import 'sync_operation.dart';

/// The outbox (ADR-0044). Every method throws rather than returning a `GPResult`: [enqueue] runs inside the entity write's transaction,
/// and a failure swallowed there would commit the entity without its mutation (golden rule 3).
abstract interface class GPSyncQueueRepository {
  /// Queues [operation] of the entity, folding it into that entity's unsent mutation when there is one. Call it inside the same
  /// `transaction()` as the entity write. [payload] is the row as written, with the server's column names.
  Future<GPSyncMutation> enqueue({required GPSyncEntityType entityType, required String entityId, required GPSyncOperation operation, required Map<String, Object?> payload});

  /// Pending and due, oldest first, and only each entity's oldest mutation left: a conflicted or failed one holds the entity's later ones
  /// until it is resolved. A row this build cannot read is marked failed and left out.
  Future<List<GPSyncMutation>> getReadyMutations({int limit});

  /// Counts the attempt and marks it in flight, before the request leaves. Send exactly what this returns: a write that folded into the
  /// mutation after [getReadyMutations] read it is in here, not in the earlier copy. Null when it is no longer pending, or an older
  /// mutation of the same entity is still queued.
  Future<GPSyncMutation?> markSending(String id);

  /// The server applied it: the mutation is deleted (golden rule 6).
  Future<void> complete(String id);

  /// Back to pending, due at [nextAttemptAt]; the attempt was already counted by [markSending].
  Future<void> scheduleRetry(String id, {required DateTime nextAttemptAt, required String errorCode});

  Future<void> markConflict(String id, {required String errorCode});

  /// Non-retryable: kept for Diagnostics, never pushed again.
  Future<void> markFailed(String id, {required String errorCode});

  /// Mutations a kill left in flight go back to pending, their attempt still counted. Run once at launch, before any push.
  Future<int> resetOrphans();

  /// Entities with any mutation left, whatever its state: each one is a change the server may not have.
  Future<int> countUnsyncedEntities();
}
