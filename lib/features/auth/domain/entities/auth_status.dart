import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'user_entity.dart';

@immutable
sealed class AuthStatus with Equatable {
  const AuthStatus();

  @override
  List<Object?> get props => const [];
}

final class AuthSignedIn extends AuthStatus {
  const AuthSignedIn(this.user);

  final UserEntity user;

  @override
  List<Object?> get props => [user];

  @override
  String toString() => 'AuthSignedIn(${user.id})';
}

final class AuthSignedOut extends AuthStatus {
  const AuthSignedOut();
}

/// No backend in this build (ADR-0038).
final class AuthLocalOnly extends AuthStatus {
  const AuthLocalOnly();
}
