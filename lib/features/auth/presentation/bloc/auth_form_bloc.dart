import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

import '../../../../app/di/injector.dart';
import '../../../../core/bloc/transformers.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/value_wrapper.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sign_in_use_case.dart';
import '../../domain/usecases/sign_up_use_case.dart';
import '../auth_form_field_enum.dart';
import '../auth_form_mode_enum.dart';

part 'auth_form_event.dart';

part 'auth_form_state.dart';

final class AuthFormBloc extends Bloc<AuthFormEvent, AuthFormState> {
  AuthFormBloc({AuthFormMode mode = AuthFormMode.signIn}) : super(AuthFormState.initial(mode)) {
    on<AuthFormEvent>(_eventHandler, transformer: sequential());
  }

  final _signIn = SignInUseCase(getIt.get<AuthRepository>());
  final _signUp = SignUpUseCase(getIt.get<AuthRepository>());

  var _isSubmitting = false;

  Future<void> _eventHandler(AuthFormEvent event, Emitter<AuthFormState> emit) async {
    switch (event) {
      case AuthFormEmailChangeEvent(:final email):
        _emailChangeHandler(email, emit);
      case AuthFormPasswordChangeEvent(:final password):
        _passwordChangeHandler(password, emit);
      case AuthFormPasswordVisibilityToggleEvent():
        _passwordVisibilityToggleHandler(emit);
      case AuthFormModeChangeEvent(:final mode):
        _modeChangeHandler(mode, emit);
      case AuthFormSubmitEvent():
        await _submitHandler(emit);
    }
  }

  void _emailChangeHandler(String email, Emitter<AuthFormState> emit) => emit(state._copyWith(failure: _failureAfterEdit(AuthFormField.email), email: email));

  void _passwordChangeHandler(String password, Emitter<AuthFormState> emit) => emit(state._copyWith(failure: _failureAfterEdit(AuthFormField.password), password: password));

  void _passwordVisibilityToggleHandler(Emitter<AuthFormState> emit) => emit(state._copyWith(isPasswordVisible: !state.isPasswordVisible));

  /// Keeps both fields; a failure from the other mode no longer applies.
  void _modeChangeHandler(AuthFormMode mode, Emitter<AuthFormState> emit) {
    if (state.isSubmitting || state.isSucceeded || mode == state.mode) return;

    emit(state._copyWith(failure: const GPValueWrapper(null), mode: mode));
  }

  Future<void> _submitHandler(Emitter<AuthFormState> emit) async {
    if (_isSubmitting || state.isSucceeded) return;

    _isSubmitting = true;
    emit(state._copyWith(failure: const GPValueWrapper(null), status: AuthFormStatus.submitting));

    final result = state.isSignUp
        ? await _signUp.execute(SignUpInput(email: state.email, password: state.password))
        : await _signIn.execute(SignInInput(email: state.email, password: state.password));
    _isSubmitting = false;
    if (isClosed) return;

    emit(switch (result) {
      GPOk() => state._copyWith(status: AuthFormStatus.succeeded),
      GPErr(:final failure) => state._copyWith(failure: GPValueWrapper(failure), status: AuthFormStatus.editing),
    });
  }

  /// An edit clears the failure it can fix: one about the edited field, or one about no field (ADR-0016).
  GPValueWrapper<GPFailure?>? _failureAfterEdit(AuthFormField edited) {
    final failure = state.failure;
    if (failure == null) return null;

    final about = AuthFormField.fromFailure(failure);
    return about == null || about == edited ? const GPValueWrapper(null) : null;
  }
}
