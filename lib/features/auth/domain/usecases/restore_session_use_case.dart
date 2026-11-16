import '../../../../core/domain/use_case.dart';
import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

final class RestoreSessionUseCase with GPUseCase<GPNoInput, void> {
  const RestoreSessionUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<GPResult<void>> execute(GPNoInput input) => _repository.restoreSession();
}
