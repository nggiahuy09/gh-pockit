import 'sync_mutation.dart';
import 'sync_push_result.dart';

/// The server side of sync (ADR-0037, ADR-0046). Nothing here retries: the engine owns the policy (system-design §6.5).
abstract interface class GPSyncRemoteDataSource {
  /// Sends [mutations] — each one as `GPSyncQueueRepository.markSending` returned it — in one request, and returns one result per
  /// mutation in the same order. Throws when no well-formed answer arrives: the transport's own error, a `TimeoutException`, or
  /// `GPMalformedPushResponse`. A throw means any of them may have been applied.
  Future<List<GPSyncPushResult>> push(List<GPSyncMutation> mutations);
}
