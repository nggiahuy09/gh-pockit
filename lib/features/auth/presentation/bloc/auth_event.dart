part of 'auth_bloc.dart';

@immutable
sealed class AuthEvent {
  const AuthEvent();
}

@immutable
final class _AuthWatchEvent extends AuthEvent {
  const _AuthWatchEvent();
}
