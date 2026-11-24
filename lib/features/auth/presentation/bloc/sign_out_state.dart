part of 'sign_out_bloc.dart';

@immutable
sealed class SignOutState with Equatable {
  const SignOutState();

  @override
  List<Object?> get props => const [];
}

final class SignOutIdleState extends SignOutState {
  const SignOutIdleState();
}

final class SignOutCheckingState extends SignOutState {
  const SignOutCheckingState();
}

/// Would lose [count] rows: explained, never offered (ADR-0042).
final class SignOutBlockedState extends SignOutState {
  const SignOutBlockedState(this.count);

  final int count;

  @override
  List<Object?> get props => [count];
}

final class SignOutConfirmingState extends SignOutState {
  const SignOutConfirmingState();
}

final class SignOutInProgressState extends SignOutState {
  const SignOutInProgressState();
}

final class SignOutDoneState extends SignOutState {
  const SignOutDoneState();
}

final class SignOutErrorState extends SignOutState {
  const SignOutErrorState(this.failure);

  final GPFailure failure;

  @override
  List<Object?> get props => [failure];
}
