part of 'accounts_bloc.dart';

@immutable
sealed class AccountsEvent {
  const AccountsEvent();
}

@immutable
final class _AccountsWatchEvent extends AccountsEvent {
  const _AccountsWatchEvent();
}
