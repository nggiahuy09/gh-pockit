part of 'home_accounts_bloc.dart';

@immutable
sealed class HomeAccountsState with Equatable {
  const HomeAccountsState(List<AccountBalance>? accounts) : _accounts = accounts;

  final List<AccountBalance>? _accounts;

  /// Null until the first list arrives.
  List<AccountBalance>? get accounts {
    final accounts = _accounts;
    return accounts == null ? null : List.unmodifiable(accounts);
  }

  @override
  List<Object?> get props => [_accounts];
}

final class HomeAccountsInitState extends HomeAccountsState {
  const HomeAccountsInitState() : super(null);
}

final class HomeAccountsLoadingState extends HomeAccountsState {
  const HomeAccountsLoadingState(super.accounts);
}

final class HomeAccountsLoadedState extends HomeAccountsState {
  const HomeAccountsLoadedState(List<AccountBalance> super.accounts);

  @override
  List<AccountBalance> get accounts => List.unmodifiable(_accounts!);
}

/// Keeps the last list: the stream stays live, so the section recovers by itself.
final class HomeAccountsLoadErrorState extends HomeAccountsState {
  const HomeAccountsLoadErrorState(super.accounts, this.failure);

  final GPFailure failure;

  @override
  List<Object?> get props => [...super.props, failure];
}
