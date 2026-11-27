import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/sync/drift_sync_queue_repository.dart';

import 'fake_clock.dart';
import 'fake_uuid_generator.dart';
import 'recording_logger.dart';

final _queues = Expando<GPDriftSyncQueueRepository>();

/// The real outbox on [db], so a repository test sees the mutation its write queued in the same transaction. One per database, as in the
/// app: two would mint the same fake ids and keys.
GPDriftSyncQueueRepository syncQueueOn(GPAppDatabase db, [FakeClock? clock]) => _queues[db] ??= () {
  final queueClock = clock ?? FakeClock();
  return GPDriftSyncQueueRepository(database: db, clock: queueClock, uuidGenerator: FakeUuidGenerator('m'), logger: RecordingLogger(queueClock));
}();
