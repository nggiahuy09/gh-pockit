import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/user_entity.dart';

/// On a build with no backend, sign-up and sign-in answer [GPBackendUnavailableFailure] and sign-out succeeds (ADR-0038).
abstract class AuthRepository {
  const AuthRepository();

  /// Signs the new user in as well.
  Future<GPResult<UserEntity>> signUp({required String email, required String password});

  Future<GPResult<UserEntity>> signIn({required String email, required String password});

  /// Signs this device out even offline. A revocation that does not reach the server is logged, not returned (ADR-0038).
  Future<GPResult<void>> signOut();
}
