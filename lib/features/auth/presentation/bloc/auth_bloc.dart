import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

import '../../../../app/di/injector.dart';
import '../../../../core/bloc/transformers.dart';
import '../../../../core/domain/use_case.dart';
import '../../domain/entities/auth_status.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/watch_auth_status_use_case.dart';

part 'auth_event.dart';

part 'auth_state.dart';

/// Watches only. The session is restored in the bootstrap, before the first frame, so the first status is already the real one.
final class AuthBloc extends Bloc<AuthEvent, AuthBlocState> {
  AuthBloc() : super(const AuthUnknownState()) {
    on<AuthEvent>(_eventHandler, transformer: restartable());

    add(const _AuthWatchEvent());
  }

  final _watchAuthStatus = WatchAuthStatusUseCase(getIt.get<AuthRepository>());

  Future<void> _eventHandler(AuthEvent event, Emitter<AuthBlocState> emit) async {
    switch (event) {
      case _AuthWatchEvent():
        await _watchHandler(emit);
    }
  }

  Future<void> _watchHandler(Emitter<AuthBlocState> emit) => emit.forEach(
    _watchAuthStatus.execute(const GPNoInput()),
    onData: (status) => switch (status) {
      AuthSignedIn(:final user) => AuthSignedInState(user),
      AuthSignedOut() => const AuthSignedOutState(),
      AuthLocalOnly() => const AuthLocalOnlyState(),
    },
  );
}
