import 'package:meta/meta.dart';

import '../../../../core/domain/loggable.dart';
import '../../../../core/domain/use_case.dart';
import '../../../../core/error/result.dart';
import '../entities/auth_credentials.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Refuses an empty or malformed email, and a password under `AuthCredentials.passwordMinLength`, before any request.
final class SignUpUseCase with GPUseCase<SignUpInput, UserEntity> {
  const SignUpUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<GPResult<UserEntity>> execute(SignUpInput input) async => switch (AuthCredentials.forSignUp(email: input.email, password: input.password)) {
    GPOk(value: final credentials) => await _repository.signUp(email: credentials.email, password: credentials.password),
    GPErr(:final failure) => GPErr(failure),
  };
}

@immutable
final class SignUpInput implements GPLoggable {
  const SignUpInput({required this.email, required this.password});

  final String email;
  final String password;

  /// Nothing: both fields are credentials (golden rule 9).
  @override
  Map<String, Object?> toLog() => const {};
}
