import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/sync/drift_sync_queue_repository.dart';

import 'fake_clock.dart';
import 'fake_uuid_generator.dart';
import 'recording_logger.dart';

final _queues = Expando<GPDriftSyncQueueRepository>();
final _clocks = Expando<FakeClock>();

/// The real outbox on [db], so a repository test sees the mutation its write queued in the same transaction. One per database, as in the
/// app: two would mint the same fake ids and keys. The first call fixes its clock; a later call naming another one is a test bug.
GPDriftSyncQueueRepository syncQueueOn(GPAppDatabase db, [FakeClock? clock]) {
  final cached = _queues[db];
  if (cached != null) {
    if (clock != null && !identical(clock, _clocks[db])) throw StateError('the queue on this database already runs on another clock');
    return cached;
  }
  final queueClock = clock ?? FakeClock();
  _clocks[db] = queueClock;
  return _queues[db] = GPDriftSyncQueueRepository(database: db, clock: queueClock, uuidGenerator: FakeUuidGenerator('m'), logger: RecordingLogger(queueClock));
}
