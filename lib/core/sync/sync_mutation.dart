import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../domain/loggable.dart';
import 'sync_entity_type.dart';
import 'sync_mutation_status.dart';
import 'sync_operation.dart';

/// One queued write of one entity (ADR-0044). [payload] is the row as it was when queued, so a retry resends exactly what the
/// [idempotencyKey] was first sent with; its `version` is the base the server checks.
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
  }) : payload = Map.unmodifiable(_flatRow(payload)),
       createdAt = _utcMillis(createdAt),
       nextAttemptAt = _utcMillis(nextAttemptAt);

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
  /// Holds only because [sending] counts the attempt before the request leaves: a mutation orphaned mid-push goes back to pending with
  /// that count kept, and the status alone could not tell it from one never sent.
  bool get isUnattempted => status == GPSyncMutationStatus.pending && attemptCount == 0;

  /// The mutation as the push hands it to the network: in flight, and already counted as an attempt (ADR-0044).
  GPSyncMutation sending() {
    if (status != GPSyncMutationStatus.pending) throw StateError('mutation $id is ${status.storageValue}, only a pending one is sent');

    return GPSyncMutation(
      id: id,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      attemptCount: attemptCount + 1,
      nextAttemptAt: nextAttemptAt,
      status: GPSyncMutationStatus.processing,
      lastErrorCode: lastErrorCode,
    );
  }

  /// This mutation carrying a later write of the same entity instead of queueing a second one (ADR-0044). Keeps [id],
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

  /// A payload is one flat row of JSON scalars: `jsonEncode` cannot fail inside the write's transaction, and nothing nested stays shared
  /// with the caller. Money is int minor units and a time epoch millis (§6), so no double either.
  static bool isFlatJsonRow(Map<String, Object?> row) => row.values.every(_isJsonScalar);

  @override
  List<Object?> get props => [id, entityType, entityId, operation, payload, idempotencyKey, createdAt, attemptCount, nextAttemptAt, status, lastErrorCode];
}

bool _isJsonScalar(Object? value) => value == null || value is String || value is int || value is bool;

/// Names the column and its type, never the value (golden rule 9).
Map<String, Object?> _flatRow(Map<String, Object?> row) {
  for (final MapEntry(:key, :value) in row.entries) {
    if (!_isJsonScalar(value)) throw ArgumentError('payload column "$key" holds a ${value.runtimeType}, not a JSON string, int, bool or null');
  }
  return row;
}

/// The table keeps epoch millis, so a time finer than that would not survive a write and a read.
DateTime _utcMillis(DateTime time) => DateTime.fromMillisecondsSinceEpoch(time.millisecondsSinceEpoch, isUtc: true);
