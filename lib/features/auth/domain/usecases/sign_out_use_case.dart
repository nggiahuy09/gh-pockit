import '../../../../core/domain/use_case.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';
import '../repositories/device_owner_repository.dart';

/// Refused while anything is unsynced; otherwise wipes the device, then ends the session (ADR-0042).
final class SignOutUseCase with GPUseCase<GPNoInput, void> {
  const SignOutUseCase(this._authRepository, this._deviceOwnerRepository);

  final AuthRepository _authRepository;
  final DeviceOwnerRepository _deviceOwnerRepository;

  @override
  Future<GPResult<void>> execute(GPNoInput input) async {
    final unsynced = await _deviceOwnerRepository.countUnsyncedChanges();
    switch (unsynced) {
      case GPErr(:final failure):
        return GPErr(failure);
      case GPOk(value: > 0):
        return const GPErr(GPValidationFailure(GPValidationCode.signOutUnsyncedChanges));
      case GPOk():
        break;
    }

    // Wipe first: if it fails, the user is still signed in and nothing is lost.
    final released = await _deviceOwnerRepository.releaseDevice();
    if (released is GPErr) return released;

    return _authRepository.signOut();
  }
}
