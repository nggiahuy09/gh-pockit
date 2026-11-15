import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

/// Bound when the env file leaves both backend keys empty (ADR-0038).
final class LocalOnlyAuthRepository implements AuthRepository {
  const LocalOnlyAuthRepository();

  @override
  Future<GPResult<UserEntity>> signUp({required String email, required String password}) async => const GPErr(GPBackendUnavailableFailure());

  @override
  Future<GPResult<UserEntity>> signIn({required String email, required String password}) async => const GPErr(GPBackendUnavailableFailure());

  @override
  Future<GPResult<void>> signOut() async => const GPOk(null);
}
