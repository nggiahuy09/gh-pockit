import '../../../../core/database/owner_id.dart';
import '../../../../core/database/settings_owner_context.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/sync/sync_queue_repository.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/uuid_generator.dart';
import '../../../categories/data/seed/category_seeder.dart';
import '../../domain/repositories/device_owner_repository.dart';
import '../daos/device_owner_dao.dart';

final class DeviceOwnerRepositoryImpl implements DeviceOwnerRepository {
  const DeviceOwnerRepositoryImpl({
    required GPClock clock,
    required DeviceOwnerDao dao,
    required GPAppLogger logger,
    required GPSettingsOwnerContext ownerContext,
    required CategorySeeder seeder,
    required GPUuidGenerator uuidGenerator,
    required GPSyncQueueRepository syncQueue,
  }) : _clock = clock,
       _dao = dao,
       _logger = logger,
       _ownerContext = ownerContext,
       _seeder = seeder,
       _uuidGenerator = uuidGenerator,
       _syncQueue = syncQueue;

  final GPClock _clock;
  final DeviceOwnerDao _dao;
  final GPAppLogger _logger;
  final GPSettingsOwnerContext _ownerContext;
  final CategorySeeder _seeder;
  final GPUuidGenerator _uuidGenerator;
  final GPSyncQueueRepository _syncQueue;

  @override
  String get ownerId => _ownerContext.current;

  @override
  Future<GPResult<int>> claimLocalData(String userId) async {
    final int moved;
    try {
      moved = await _dao.claimLocalRows(userId: userId, nowMillis: _clock.nowEpochMillis(), uuidGenerator: _uuidGenerator, syncQueue: _syncQueue);
    } on Exception catch (error, stackTrace) {
      // Rolled back; the next launch claims again.
      _logger.error('local data claim failed', fields: {'user_id': userId}, error: error, stackTrace: stackTrace);
      return const GPErr(GPDatabaseFailure());
    }

    // Before any await: open queries switch to the new owner at once.
    _ownerContext.adopt(userId);
    _logger.info('local data claimed', fields: {'user_id': userId, 'count': moved});
    return GPOk(moved);
  }

  @override
  Future<GPResult<int>> backfillOutbox() async {
    final ownerId = _ownerContext.current;
    try {
      final queued = await _dao.backfillOutbox(ownerId: ownerId, syncQueue: _syncQueue);
      if (queued > 0) _logger.info('outbox backfilled', fields: {'user_id': ownerId, 'count': queued});
      return GPOk(queued);
    } on Exception catch (error, stackTrace) {
      // Rolled back; the next launch tries again.
      _logger.error('outbox backfill failed', fields: {'user_id': ownerId}, error: error, stackTrace: stackTrace);
      return const GPErr(GPDatabaseFailure());
    }
  }

  @override
  Future<GPResult<int>> countUnsyncedChanges() async {
    try {
      return GPOk(await _dao.countUnsynced());
    } on Exception catch (error, stackTrace) {
      _logger.error('unsynced count failed', error: error, stackTrace: stackTrace);
      return const GPErr(GPDatabaseFailure());
    }
  }

  @override
  Future<GPResult<void>> releaseDevice() async {
    final ownerId = _ownerContext.current;
    // Unclaimed rows belong to nobody's account: never wipe them.
    if (ownerId == localOwnerId) return const GPOk(null);

    final int deleted;
    try {
      deleted = await _dao.wipeOwnerRows(ownerId);
    } on Exception catch (error, stackTrace) {
      _logger.error('device release failed', fields: {'user_id': ownerId}, error: error, stackTrace: stackTrace);
      return const GPErr(GPDatabaseFailure());
    }

    _ownerContext.adopt(localOwnerId);
    try {
      await _seeder.seedDefaults();
    } on Exception catch (error, stackTrace) {
      // The next launch seeds them; the sign-out itself is done.
      _logger.error('reseed after release failed', error: error, stackTrace: stackTrace);
    }
    _logger.info('device released', fields: {'user_id': ownerId, 'count': deleted});
    return const GPOk(null);
  }
}
