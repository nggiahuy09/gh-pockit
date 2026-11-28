import 'package:supabase/supabase.dart';

import 'sync_mutation.dart';
import 'sync_push_result.dart';
import 'sync_push_wire.dart';
import 'sync_remote_data_source.dart';

/// Takes `SupabaseClient.rest`, whose HTTP client adds the signed-in user's token to every request.
final class GPSupabaseSyncRemoteDataSource implements GPSyncRemoteDataSource {
  const GPSupabaseSyncRemoteDataSource({required PostgrestClient rest, this.requestTimeout = const Duration(seconds: 30)}) : _rest = rest;

  final PostgrestClient _rest;

  /// Postgrest sets none by default: a hung push would hold the sync lock until the OS gives up on the socket.
  final Duration requestTimeout;

  @override
  Future<List<GPSyncPushResult>> push(List<GPSyncMutation> mutations) async {
    if (mutations.isEmpty) return const [];

    final request = encodePushRequest(mutations);
    // Postgrest retries only GET, but a push must never be resent behind the engine's back (system-design §6.5).
    final body = await _rest.rpc<Object?>(pushFunctionName, params: {pushMutationsParam: request}).retry(enabled: false, requestTimeout: requestTimeout);

    return decodePushResponse(body, mutations);
  }
}
