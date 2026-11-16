part of 'auth_form_bloc.dart';

@immutable
final class AuthFormState with Equatable {
  const AuthFormState({
    required this.failure,
    required this.mode,
    required this.status,
    required this.email,
    required this.password,
    required this.isPasswordVisible,
  });

  const AuthFormState.initial(this.mode) : failure = null, status = AuthFormStatus.editing, email = '', password = '', isPasswordVisible = false;

  final GPFailure? failure;
  final AuthFormMode mode;
  final AuthFormStatus status;
  final String email;
  final String password;
  final bool isPasswordVisible;

  bool get isSignUp => mode == AuthFormMode.signUp;

  bool get isSubmitting => status == AuthFormStatus.submitting;

  bool get isSucceeded => status == AuthFormStatus.succeeded;

  AuthFormField? get failedField {
    final failure = this.failure;
    return failure == null ? null : AuthFormField.fromFailure(failure);
  }

  /// On sign-up, the one refusal a sign-in fixes: offered as a switch that keeps the email.
  bool get isEmailTaken => isSignUp && failure == const GPValidationFailure(GPValidationCode.authEmailTaken);

  @override
  List<Object?> get props => [failure, mode, status, email, password, isPasswordVisible];

  AuthFormState _copyWith({GPValueWrapper<GPFailure?>? failure, AuthFormMode? mode, AuthFormStatus? status, String? email, String? password, bool? isPasswordVisible}) =>
      AuthFormState(
        failure: failure == null ? this.failure : failure.value,
        mode: mode ?? this.mode,
        status: status ?? this.status,
        email: email ?? this.email,
        password: password ?? this.password,
        isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      );

  /// No email or password: states can end up in logs and failed `expect`s (golden rule 9).
  @override
  String toString() => 'AuthFormState(mode: ${mode.name}, status: ${status.name}, failure: $failure)';
}

/// `succeeded` is terminal: the view closes on it.
enum AuthFormStatus { editing, submitting, succeeded }
