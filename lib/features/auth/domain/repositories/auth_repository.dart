import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/auth_status.dart';
import '../entities/user_entity.dart';

/// With no backend, sign-up and sign-in fail with [GPBackendUnavailableFailure] (ADR-0038).
abstract class AuthRepository {
  const AuthRepository();

  /// The current status at once, then each change; never an error.
  Stream<AuthStatus> watchAuthStatus();

  /// No network call; once, at launch.
  Future<GPResult<void>> restoreSession();

  /// Signs the new user in as well.
  Future<GPResult<UserEntity>> signUp({required String email, required String password});

  Future<GPResult<UserEntity>> signIn({required String email, required String password});

  /// Even offline: a failed revoke is logged, not returned.
  Future<GPResult<void>> signOut();
}
