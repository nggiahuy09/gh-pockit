part of 'auth_form_bloc.dart';

@immutable
sealed class AuthFormEvent {
  const AuthFormEvent();
}

@immutable
final class AuthFormEmailChangeEvent extends AuthFormEvent {
  const AuthFormEmailChangeEvent(this.email);

  final String email;
}

@immutable
final class AuthFormPasswordChangeEvent extends AuthFormEvent {
  const AuthFormPasswordChangeEvent(this.password);

  final String password;
}

@immutable
final class AuthFormPasswordVisibilityToggleEvent extends AuthFormEvent {
  const AuthFormPasswordVisibilityToggleEvent();
}

@immutable
final class AuthFormModeChangeEvent extends AuthFormEvent {
  const AuthFormModeChangeEvent(this.mode);

  final AuthFormMode mode;
}

@immutable
final class AuthFormSubmitEvent extends AuthFormEvent {
  const AuthFormSubmitEvent();
}
