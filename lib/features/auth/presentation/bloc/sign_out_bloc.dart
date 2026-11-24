import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

import '../../../../app/di/injector.dart';
import '../../../../core/bloc/transformers.dart';
import '../../../../core/domain/use_case.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/device_owner_repository.dart';
import '../../domain/usecases/count_unsynced_changes_use_case.dart';
import '../../domain/usecases/sign_out_use_case.dart';

part 'sign_out_event.dart';

part 'sign_out_state.dart';

final class SignOutBloc extends Bloc<SignOutEvent, SignOutState> {
  SignOutBloc() : super(const SignOutIdleState()) {
    on<SignOutEvent>(_eventHandler, transformer: sequential());
  }

  // Late: Settings' listener builds the bloc on every visit, and a local-only build never taps Sign out.
  late final _countUnsyncedChanges = CountUnsyncedChangesUseCase(getIt.get<DeviceOwnerRepository>());
  late final _signOut = SignOutUseCase(getIt.get<AuthRepository>(), getIt.get<DeviceOwnerRepository>());

  Future<void> _eventHandler(SignOutEvent event, Emitter<SignOutState> emit) async {
    switch (event) {
      case SignOutRequestEvent():
        await _requestHandler(emit);
      case SignOutConfirmEvent():
        await _confirmHandler(emit);
      case SignOutCancelEvent():
        emit(const SignOutIdleState());
    }
  }

  Future<void> _requestHandler(Emitter<SignOutState> emit) async {
    // Done too: the same Settings visit can sign back in and out again.
    if (state is! SignOutIdleState && state is! SignOutErrorState && state is! SignOutDoneState) return;

    emit(const SignOutCheckingState());
    emit(switch (await _countUnsyncedChanges.execute(const GPNoInput())) {
      GPOk(value: final count) when count > 0 => SignOutBlockedState(count),
      GPOk() => const SignOutConfirmingState(),
      GPErr(:final failure) => SignOutErrorState(failure),
    });
  }

  Future<void> _confirmHandler(Emitter<SignOutState> emit) async {
    if (state is! SignOutConfirmingState) return;

    emit(const SignOutInProgressState());
    emit(switch (await _signOut.execute(const GPNoInput())) {
      GPOk() => const SignOutDoneState(),
      GPErr(:final failure) => SignOutErrorState(failure),
    });
  }
}
