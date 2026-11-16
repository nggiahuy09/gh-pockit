import '../../../../core/domain/use_case.dart';
import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

/// Ends the session only. Wiping this device's data is a separate step, with its own check for unsynced rows.
final class SignOutUseCase with GPUseCase<GPNoInput, void> {
  const SignOutUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<GPResult<void>> execute(GPNoInput input) => _repository.signOut();
}
