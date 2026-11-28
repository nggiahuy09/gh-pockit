import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../domain/loggable.dart';

/// The server's answer to one pushed mutation (ADR-0046). A batch answers every mutation it was sent, once.
@immutable
sealed class GPSyncPushResult with Equatable implements GPLoggable {
  const GPSyncPushResult(this.mutationId);

  final String mutationId;
}

/// Written. The row now carries the server's stamps, not the ones it was sent with (ADR-0036).
final class GPSyncPushApplied extends GPSyncPushResult {
  GPSyncPushApplied({required String mutationId, required this.serverVersion, required DateTime serverUpdatedAt})
    : serverUpdatedAt = DateTime.fromMillisecondsSinceEpoch(serverUpdatedAt.millisecondsSinceEpoch, isUtc: true),
      super(mutationId);

  final int serverVersion;
  final DateTime serverUpdatedAt;

  @override
  Map<String, Object?> toLog() => {'mutation_id': mutationId, 'result': 'applied', 'server_version': serverVersion};

  @override
  List<Object?> get props => [mutationId, serverVersion, serverUpdatedAt];
}

/// The payload's `version` was not the server's: nothing was written. [remote] is the server's row, so a conflict can show both sides
/// (system-design §7).
final class GPSyncPushConflict extends GPSyncPushResult {
  GPSyncPushConflict({required String mutationId, required Map<String, Object?> remote}) : remote = Map.unmodifiable(remote), super(mutationId);

  final Map<String, Object?> remote;

  int? get serverVersion => switch (remote['version']) {
    final int version => version,
    _ => null,
  };

  /// No [remote]: it holds amounts and notes (golden rule 9).
  @override
  Map<String, Object?> toLog() => {'mutation_id': mutationId, 'result': 'conflict', 'server_version': serverVersion};

  @override
  List<Object?> get props => [mutationId, remote];
}

/// Refused for good: sending it again gets the same answer. [code] names the rule (a constraint name, or `not_found`), never a value.
final class GPSyncPushRejected extends GPSyncPushResult {
  const GPSyncPushRejected({required String mutationId, required this.code}) : super(mutationId);

  final String code;

  @override
  Map<String, Object?> toLog() => {'mutation_id': mutationId, 'result': 'rejected', 'code': code};

  @override
  List<Object?> get props => [mutationId, code];
}
