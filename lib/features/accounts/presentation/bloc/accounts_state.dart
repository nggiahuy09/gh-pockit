part of 'accounts_bloc.dart';

@immutable
sealed class AccountsState with Equatable {
  const AccountsState(List<AccountBalance>? balances) : _balances = balances;

  final List<AccountBalance>? _balances;

  /// Null until the first list arrives: loading, not empty.
  List<AccountBalance>? get balances {
    final balances = _balances;
    return balances == null ? null : List.unmodifiable(balances);
  }

  @override
  List<Object?> get props => [_balances];
}

final class AccountsInitState extends AccountsState {
  const AccountsInitState() : super(null);
}

final class AccountsLoadingState extends AccountsState {
  const AccountsLoadingState(super.balances);
}

final class AccountsLoadedState extends AccountsState {
  const AccountsLoadedState(List<AccountBalance> super.balances);

  @override
  List<AccountBalance> get balances => List.unmodifiable(_balances!);
}

/// Keeps the last list: the query stays live, so the page recovers by itself with the next one.
final class AccountsLoadErrorState extends AccountsState {
  const AccountsLoadErrorState(super.balances, this.failure);

  final GPFailure failure;

  @override
  List<Object?> get props => [...super.props, failure];
}
