part of 'home_accounts_bloc.dart';

@immutable
sealed class HomeAccountsEvent {
  const HomeAccountsEvent();
}

@immutable
final class _HomeAccountsWatchEvent extends HomeAccountsEvent {
  const _HomeAccountsWatchEvent();
}
