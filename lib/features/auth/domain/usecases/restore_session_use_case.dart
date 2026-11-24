import '../../../../core/domain/use_case.dart';
import '../../../../core/error/result.dart';
import '../entities/auth_status.dart';
import '../repositories/auth_repository.dart';
import '../repositories/device_owner_repository.dart';
import 'claim_local_data_use_case.dart';

/// Also claims for the restored user if the last claim did not land (ADR-0040).
final class RestoreSessionUseCase with GPUseCase<GPNoInput, void> {
  const RestoreSessionUseCase(this._authRepository, this._deviceOwnerRepository);

  final AuthRepository _authRepository;
  final DeviceOwnerRepository _deviceOwnerRepository;

  @override
  Future<GPResult<void>> execute(GPNoInput input) async {
    final restored = await _authRepository.restoreSession();
    if (restored is GPErr) return restored;

    if (await _authRepository.watchAuthStatus().first case AuthSignedIn(:final user)) {
      final claimed = await ClaimLocalDataUseCase(_authRepository, _deviceOwnerRepository).execute(ClaimLocalDataInput(user.id));
      if (claimed case GPErr(:final failure)) return GPErr(failure);
    }
    return const GPOk(null);
  }
}
