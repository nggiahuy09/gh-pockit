import '../../../../core/database/settings_owner_context.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/uuid_generator.dart';
import '../../domain/repositories/device_owner_repository.dart';
import '../daos/device_owner_dao.dart';

final class DeviceOwnerRepositoryImpl implements DeviceOwnerRepository {
  const DeviceOwnerRepositoryImpl({
    required GPClock clock,
    required DeviceOwnerDao dao,
    required GPAppLogger logger,
    required GPSettingsOwnerContext ownerContext,
    required GPUuidGenerator uuidGenerator,
  }) : _clock = clock,
       _dao = dao,
       _logger = logger,
       _ownerContext = ownerContext,
       _uuidGenerator = uuidGenerator;

  final GPClock _clock;
  final DeviceOwnerDao _dao;
  final GPAppLogger _logger;
  final GPSettingsOwnerContext _ownerContext;
  final GPUuidGenerator _uuidGenerator;

  @override
  String get ownerId => _ownerContext.current;

  @override
  Future<GPResult<int>> claimLocalData(String userId) async {
    final int moved;
    try {
      moved = await _dao.claimLocalRows(userId: userId, nowMillis: _clock.nowEpochMillis(), uuidGenerator: _uuidGenerator);
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
}
