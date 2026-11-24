part of 'sign_out_bloc.dart';

@immutable
sealed class SignOutEvent {
  const SignOutEvent();
}

/// The tap: counts what a sign-out would lose before asking.
@immutable
final class SignOutRequestEvent extends SignOutEvent {
  const SignOutRequestEvent();
}

@immutable
final class SignOutConfirmEvent extends SignOutEvent {
  const SignOutConfirmEvent();
}

@immutable
final class SignOutCancelEvent extends SignOutEvent {
  const SignOutCancelEvent();
}
