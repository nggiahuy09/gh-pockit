import 'sync_mutation.dart';
import 'sync_mutation_status.dart';
import 'sync_push_result.dart';

/// The Postgres function a push calls over RPC (ADR-0037, ADR-0046).
const String pushFunctionName = 'push_mutations';

/// Its one argument: the batch as a JSON array.
const String pushMutationsParam = 'mutations';

/// The function refuses a longer batch: one savepoint per mutation, and Postgres slows past 64 in one transaction (ADR-0046).
const int maxPushBatchSize = 64;

/// No `base_version`: the base is the payload's `version` (ADR-0044, Amended — T3), and a second copy could only disagree with it.
/// No `owner_id` beside the payload's: the server takes the owner from the token (ADR-0034).
List<Map<String, Object?>> encodePushRequest(List<GPSyncMutation> mutations) {
  if (mutations.length > maxPushBatchSize) throw ArgumentError('a push carries at most $maxPushBatchSize mutations, not ${mutations.length}');
  final ids = <String>{};
  for (final mutation in mutations) {
    // Only what `markSending` returned goes out: counted as an attempt before it leaves (ADR-0044).
    if (mutation.status != GPSyncMutationStatus.processing) throw ArgumentError('mutation ${mutation.id} is ${mutation.status.storageValue}, not processing');
    if (!ids.add(mutation.id)) throw ArgumentError('mutation ${mutation.id} is in the batch twice');
  }

  return [
    for (final mutation in mutations)
      {
        'mutation_id': mutation.id,
        'entity_type': mutation.entityType.storageValue,
        'entity_id': mutation.entityId,
        'operation': mutation.operation.storageValue,
        'idempotency_key': mutation.idempotencyKey,
        'payload': mutation.payload,
      },
  ];
}

/// One result per mutation in [sent], in [sent]'s order. Anything else — an unknown status, a missing or extra answer — throws
/// [GPMalformedPushResponse] rather than being guessed at: a mutation is never completed on an answer this build does not understand.
List<GPSyncPushResult> decodePushResponse(Object? body, List<GPSyncMutation> sent) {
  if (body is! List<Object?>) throw const GPMalformedPushResponse(GPPushResponseProblem.notAList);

  final expected = {for (final mutation in sent) mutation.id};
  final byId = <String, GPSyncPushResult>{};
  for (final item in body) {
    final result = _decodeResult(item);
    if (!expected.contains(result.mutationId)) throw const GPMalformedPushResponse(GPPushResponseProblem.unknownMutation);
    if (byId.containsKey(result.mutationId)) throw const GPMalformedPushResponse(GPPushResponseProblem.duplicateResult);
    byId[result.mutationId] = result;
  }
  if (byId.length != expected.length) throw const GPMalformedPushResponse(GPPushResponseProblem.missingResult);

  return [for (final mutation in sent) byId[mutation.id]!];
}

GPSyncPushResult _decodeResult(Object? item) {
  if (item is! Map<String, Object?>) throw const GPMalformedPushResponse(GPPushResponseProblem.notAnObject);

  final mutationId = _field<String>(item, 'mutation_id');
  return switch (_field<String>(item, 'status')) {
    'applied' => GPSyncPushApplied(
      mutationId: mutationId,
      serverVersion: _field<int>(item, 'server_version'),
      serverUpdatedAt: DateTime.fromMillisecondsSinceEpoch(_field<int>(item, 'server_updated_at'), isUtc: true),
    ),
    'conflict' => GPSyncPushConflict(mutationId: mutationId, remote: _remoteRow(item)),
    'rejected' => GPSyncPushRejected(mutationId: mutationId, code: _field<String>(item, 'code')),
    _ => throw const GPMalformedPushResponse(GPPushResponseProblem.unknownStatus),
  };
}

Map<String, Object?> _remoteRow(Map<String, Object?> item) {
  final remote = _field<Map<String, Object?>>(item, 'remote');
  if (!GPSyncMutation.isFlatJsonRow(remote)) throw const GPMalformedPushResponse(GPPushResponseProblem.badField);
  return remote;
}

T _field<T extends Object>(Map<String, Object?> item, String key) => switch (item[key]) {
  final T value when value is! String || value.isNotEmpty => value,
  _ => throw const GPMalformedPushResponse(GPPushResponseProblem.badField),
};

/// Log-safe: names the check, never the body (golden rule 9).
enum GPPushResponseProblem { notAList, notAnObject, badField, unknownStatus, unknownMutation, duplicateResult, missingResult }

/// The server answered, but not in the shape of ADR-0046.
final class GPMalformedPushResponse implements Exception {
  const GPMalformedPushResponse(this.problem);

  final GPPushResponseProblem problem;

  @override
  String toString() => 'GPMalformedPushResponse(${problem.name})';
}
