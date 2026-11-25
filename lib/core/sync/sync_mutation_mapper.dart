import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../database/database.dart';
import '../error/failure.dart';
import 'sync_entity_type.dart';
import 'sync_mutation.dart';
import 'sync_mutation_status.dart';
import 'sync_operation.dart';

/// Not a `GPResult`, as for the entity mappers: the caller needs the [GPSyncMutationMapperReason] for the log.
sealed class GPSyncMutationMapping {
  const GPSyncMutationMapping();
}

final class GPMappedSyncMutation extends GPSyncMutationMapping {
  const GPMappedSyncMutation(this.mutation);

  final GPSyncMutation mutation;
}

final class GPUnmappableSyncMutationRow extends GPSyncMutationMapping {
  const GPUnmappableSyncMutationRow(this.reason);

  final GPSyncMutationMapperReason reason;

  GPFailure get failure => const GPDatabaseFailure();
}

extension GPSyncMutationRowMapper on SyncMutationRow {
  GPSyncMutationMapping toDomain() {
    // No vocabulary CHECK in the table (ADR-0044), so an unknown value is refused here rather than guessed.
    final type = GPSyncEntityType.fromStorage(entityType);
    if (type == null) return const GPUnmappableSyncMutationRow(GPSyncMutationMapperReason.unknownEntityType);
    final op = GPSyncOperation.fromStorage(operation);
    if (op == null) return const GPUnmappableSyncMutationRow(GPSyncMutationMapperReason.unknownOperation);
    final state = GPSyncMutationStatus.fromStorage(status);
    if (state == null) return const GPUnmappableSyncMutationRow(GPSyncMutationMapperReason.unknownStatus);
    final decoded = _decodePayload(payloadJson);
    if (decoded == null || !GPSyncMutation.isFlatJsonRow(decoded)) return const GPUnmappableSyncMutationRow(GPSyncMutationMapperReason.malformedPayload);

    return GPMappedSyncMutation(
      GPSyncMutation(
        id: id,
        entityType: type,
        entityId: entityId,
        operation: op,
        payload: decoded,
        idempotencyKey: idempotencyKey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true),
        attemptCount: attemptCount,
        nextAttemptAt: DateTime.fromMillisecondsSinceEpoch(nextAttemptAt, isUtc: true),
        status: state,
        lastErrorCode: lastErrorCode,
      ),
    );
  }
}

extension GPSyncMutationMapper on GPSyncMutation {
  /// `.insert`, so a new non-null column is a compile error here until it is set.
  SyncMutationsTableCompanion toInsert() => SyncMutationsTableCompanion.insert(
    id: id,
    entityType: entityType.storageValue,
    entityId: entityId,
    operation: operation.storageValue,
    payloadJson: jsonEncode(payload),
    idempotencyKey: idempotencyKey,
    createdAt: createdAt.millisecondsSinceEpoch,
    attemptCount: attemptCount,
    nextAttemptAt: nextAttemptAt.millisecondsSinceEpoch,
    status: status.storageValue,
    lastErrorCode: Value(lastErrorCode),
  );
}

/// Goes to the log, so a reason names a check and never a value from the row (golden rule 9).
enum GPSyncMutationMapperReason { unknownEntityType, unknownOperation, unknownStatus, malformedPayload }

/// A payload is always a JSON object: the row's columns by name.
Map<String, Object?>? _decodePayload(String json) {
  try {
    return switch (jsonDecode(json)) {
      final Map<String, Object?> object => object,
      _ => null,
    };
  } on FormatException {
    return null;
  }
}
