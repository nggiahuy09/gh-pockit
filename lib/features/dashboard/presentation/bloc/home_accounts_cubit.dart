import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_balance.dart';
import 'package:ghpockit/features/accounts/domain/usecases/watch_account_balances_use_case.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:meta/meta.dart';

@immutable
final class HomeAccountsState {
  const HomeAccountsState({this.accounts, this.failure});

  /// Null until the first list arrives.
  final List<AccountBalance>? accounts;

  /// Cleared by the next list: the stream stays live, so the section recovers by itself.
  final GPFailure? failure;

  bool get isLoading => accounts == null && failure == null;
}

/// The accounts section of Home with their balances, the same the Accounts tab shows, live from the local database (ADR-0013).
class HomeAccountsCubit extends Cubit<HomeAccountsState> {
  HomeAccountsCubit() : super(const HomeAccountsState());

  final WatchAccountBalancesUseCase _watchBalances = WatchAccountBalancesUseCase(transactionRepository: getIt<TransactionRepository>());
  StreamSubscription<List<AccountBalance>>? _subscription;

  void start() {
    _subscription ??= _watchBalances().listen(
      (List<AccountBalance> accounts) => emit(HomeAccountsState(accounts: List<AccountBalance>.unmodifiable(accounts))),
      onError: (Object error, StackTrace stackTrace) {
        // Anything but a `GPFailure` is a bug: rethrown, not shown as a sentence (ADR-0006).
        if (error is! GPFailure) Error.throwWithStackTrace(error, stackTrace);
        emit(HomeAccountsState(accounts: state.accounts, failure: error));
      },
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
