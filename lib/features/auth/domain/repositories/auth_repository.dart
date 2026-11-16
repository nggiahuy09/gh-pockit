import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/auth_status.dart';
import '../entities/user_entity.dart';

/// On a build with no backend, sign-up and sign-in answer [GPBackendUnavailableFailure] and sign-out succeeds (ADR-0038).
abstract class AuthRepository {
  const AuthRepository();

  /// The current status at once, then each change. Never an error: a refresh that fails offline keeps the session (offline-first).
  Stream<AuthStatus> watchAuthStatus();

  /// Puts back the session this device kept, with no network call, and keeps every later one. Once, at launch, before the first frame.
  Future<GPResult<void>> restoreSession();

  /// Signs the new user in as well.
  Future<GPResult<UserEntity>> signUp({required String email, required String password});

  Future<GPResult<UserEntity>> signIn({required String email, required String password});

  /// Signs this device out even offline. A revocation that does not reach the server is logged, not returned (ADR-0038).
  Future<GPResult<void>> signOut();
}
