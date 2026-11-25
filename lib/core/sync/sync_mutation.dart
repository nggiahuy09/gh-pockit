import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../domain/loggable.dart';
import 'sync_entity_type.dart';
import 'sync_mutation_status.dart';
import 'sync_operation.dart';

/// One queued write of one entity (ADR-0044). [payload] is the row as it was when queued, so a retry resends exactly what the
/// [idempotencyKey] was first sent with; its `version` is the base the server checks (W13 plan, decision E).
@immutable
final class GPSyncMutation with Equatable implements GPLoggable {
  GPSyncMutation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required Map<String, Object?> payload,
    required this.idempotencyKey,
    required DateTime createdAt,
    required this.attemptCount,
    required DateTime nextAttemptAt,
    required this.status,
    this.lastErrorCode,
  }) : payload = Map.unmodifiable(payload),
       createdAt = createdAt.toUtc(),
       nextAttemptAt = nextAttemptAt.toUtc();

  /// Ready at once: [nextAttemptAt] is [createdAt], never null (ADR-0044).
  factory GPSyncMutation.enqueued({
    required String id,
    required GPSyncEntityType entityType,
    required String entityId,
    required GPSyncOperation operation,
    required Map<String, Object?> payload,
    required String idempotencyKey,
    required DateTime createdAt,
  }) => GPSyncMutation(
    id: id,
    entityType: entityType,
    entityId: entityId,
    operation: operation,
    payload: payload,
    idempotencyKey: idempotencyKey,
    createdAt: createdAt,
    attemptCount: 0,
    nextAttemptAt: createdAt,
    status: GPSyncMutationStatus.pending,
  );

  final String id;
  final GPSyncEntityType entityType;
  final String entityId;
  final GPSyncOperation operation;
  final Map<String, Object?> payload;
  final String idempotencyKey;
  final DateTime createdAt;
  final int attemptCount;
  final DateTime nextAttemptAt;
  final GPSyncMutationStatus status;

  /// A code, never a server message (golden rule 9).
  final String? lastErrorCode;

  /// Never sent, so nothing reached the server under [idempotencyKey], and a later write of the same entity may still fold into it.
  bool get isUnattempted => status == GPSyncMutationStatus.pending && attemptCount == 0;

  /// This mutation carrying a later write of the same entity instead of queueing a second one (W13 plan, decision D). Keeps [id],
  /// [idempotencyKey] and [createdAt], so the entity keeps its place in the queue.
  GPSyncMutation coalescedWith({required GPSyncOperation operation, required Map<String, Object?> payload}) {
    // Once sent, the server may hold this key's answer for the old payload: a new payload under it would be answered with that.
    if (!isUnattempted) throw StateError('mutation $id was already attempted');

    return GPSyncMutation(
      id: id,
      entityType: entityType,
      entityId: entityId,
      operation: this.operation.followedBy(operation),
      payload: payload,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      attemptCount: attemptCount,
      nextAttemptAt: nextAttemptAt,
      status: status,
    );
  }

  /// No [payload]: it holds amounts and notes (golden rule 9).
  @override
  Map<String, Object?> toLog() => {
    'mutation_id': id,
    'entity_type': entityType.storageValue,
    'entity_id': entityId,
    'operation': operation.storageValue,
    'status': status.storageValue,
    'attempt_count': attemptCount,
    if (lastErrorCode != null) 'last_error_code': lastErrorCode,
  };

  @override
  List<Object?> get props => [id, entityType, entityId, operation, payload, idempotencyKey, createdAt, attemptCount, nextAttemptAt, status, lastErrorCode];
}
