import 'package:meta/meta.dart';

import '../../../../core/database/owner_id.dart';
import '../../../../core/domain/loggable.dart';
import '../../../../core/domain/use_case.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';
import '../repositories/device_owner_repository.dart';

/// After a sign-in, and at launch for a restored session: the device's data becomes the user's, or the user is refused (ADR-0040).
final class ClaimLocalDataUseCase with GPUseCase<ClaimLocalDataInput, int> {
  const ClaimLocalDataUseCase(this._authRepository, this._deviceOwnerRepository);

  final AuthRepository _authRepository;
  final DeviceOwnerRepository _deviceOwnerRepository;

  @override
  Future<GPResult<int>> execute(ClaimLocalDataInput input) async {
    final owner = _deviceOwnerRepository.ownerId;
    if (owner == input.userId) return const GPOk(0);
    if (owner == localOwnerId) return _deviceOwnerRepository.claimLocalData(input.userId);

    // Another account's rows are still here: its session ended without a sign-out. Wiping them is a sign-out's job, never a sign-in's.
    await _authRepository.signOut();
    return const GPErr(GPValidationFailure(GPValidationCode.authDeviceOwnedByAnotherAccount));
  }
}

@immutable
final class ClaimLocalDataInput implements GPLoggable {
  const ClaimLocalDataInput(this.userId);

  final String userId;

  @override
  Map<String, Object?> toLog() => {'user_id': userId};
}

/// Shared by sign-in and sign-up. Only another account's data undoes the sign-in; a claim that fails in the database leaves the rows 'local'
/// and is retried at the next launch, so the user stays signed in.
Future<GPResult<UserEntity>> claimAfterSignIn(UserEntity user, {required AuthRepository authRepository, required DeviceOwnerRepository deviceOwnerRepository}) async {
  final claimed = await ClaimLocalDataUseCase(authRepository, deviceOwnerRepository).execute(ClaimLocalDataInput(user.id));
  return switch (claimed) {
    GPErr(failure: GPValidationFailure(code: GPValidationCode.authDeviceOwnedByAnotherAccount)) => const GPErr(
      GPValidationFailure(GPValidationCode.authDeviceOwnedByAnotherAccount),
    ),
    GPOk() || GPErr() => GPOk(user),
  };
}
