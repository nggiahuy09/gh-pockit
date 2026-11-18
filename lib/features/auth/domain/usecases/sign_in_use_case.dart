import 'package:meta/meta.dart';

import '../../../../core/domain/loggable.dart';
import '../../../../core/domain/use_case.dart';
import '../../../../core/error/result.dart';
import '../entities/auth_credentials.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';
import '../repositories/device_owner_repository.dart';
import 'claim_local_data_use_case.dart';

/// Refuses an empty or malformed email and an empty password before any request.
final class SignInUseCase with GPUseCase<SignInInput, UserEntity> {
  const SignInUseCase(this._authRepository, this._deviceOwnerRepository);

  final AuthRepository _authRepository;
  final DeviceOwnerRepository _deviceOwnerRepository;

  @override
  Future<GPResult<UserEntity>> execute(SignInInput input) async {
    final signedIn = switch (AuthCredentials.forSignIn(email: input.email, password: input.password)) {
      GPOk(value: final credentials) => await _authRepository.signIn(email: credentials.email, password: credentials.password),
      GPErr(:final failure) => GPErr<UserEntity>(failure),
    };
    if (signedIn case GPOk(value: final user)) return claimAfterSignIn(user, authRepository: _authRepository, deviceOwnerRepository: _deviceOwnerRepository);

    return signedIn;
  }
}

@immutable
final class SignInInput implements GPLoggable {
  const SignInInput({required this.email, required this.password});

  final String email;
  final String password;

  /// Nothing: both fields are credentials (golden rule 9).
  @override
  Map<String, Object?> toLog() => const {};
}
