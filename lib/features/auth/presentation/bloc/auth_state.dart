part of 'auth_bloc.dart';

/// Not `AuthState`: GoTrue has one, and the two would meet in any file that touches both.
@immutable
sealed class AuthBlocState with Equatable {
  const AuthBlocState();

  @override
  List<Object?> get props => const [];
}

/// Before the first status; blocks nothing.
final class AuthUnknownState extends AuthBlocState {
  const AuthUnknownState();
}

final class AuthSignedInState extends AuthBlocState {
  const AuthSignedInState(this.user);

  final UserEntity user;

  @override
  List<Object?> get props => [user];

  @override
  String toString() => 'AuthSignedInState(${user.id})';
}

final class AuthSignedOutState extends AuthBlocState {
  const AuthSignedOutState();
}

final class AuthLocalOnlyState extends AuthBlocState {
  const AuthLocalOnlyState();
}
