import '../../../../core/domain/use_case.dart';
import '../entities/auth_status.dart';
import '../repositories/auth_repository.dart';

final class WatchAuthStatusUseCase with GPStreamUseCase<GPNoInput, AuthStatus> {
  const WatchAuthStatusUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Stream<AuthStatus> execute(GPNoInput input) => _repository.watchAuthStatus();
}
