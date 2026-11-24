import '../../../../core/domain/use_case.dart';
import '../../../../core/error/result.dart';
import '../repositories/device_owner_repository.dart';

final class CountUnsyncedChangesUseCase with GPUseCase<GPNoInput, int> {
  const CountUnsyncedChangesUseCase(this._repository);

  final DeviceOwnerRepository _repository;

  @override
  Future<GPResult<int>> execute(GPNoInput input) => _repository.countUnsyncedChanges();
}
