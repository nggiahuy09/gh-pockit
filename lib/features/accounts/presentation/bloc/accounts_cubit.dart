import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_balance.dart';
import 'package:ghpockit/features/accounts/domain/usecases/watch_account_balances_use_case.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:meta/meta.dart';

@immutable
final class AccountsState {
  const AccountsState({this.balances, this.failure});

  /// Null until the first list arrives: loading, not empty.
  final List<AccountBalance>? balances;

  /// Cleared by the next list: the query stays live, so the page recovers by itself.
  final GPFailure? failure;
}

/// The Accounts tab: every account with its balance, live from the local database.
class AccountsCubit extends Cubit<AccountsState> {
  AccountsCubit() : super(const AccountsState());

  final WatchAccountBalancesUseCase _watchBalances = WatchAccountBalancesUseCase(transactionRepository: getIt<TransactionRepository>());
  StreamSubscription<List<AccountBalance>>? _subscription;

  void start() {
    _subscription ??= _watchBalances().listen(
      (List<AccountBalance> balances) => emit(AccountsState(balances: List<AccountBalance>.unmodifiable(balances))),
      onError: (Object error, StackTrace stackTrace) {
        // Anything but a `GPFailure` is a bug: rethrown, not shown as a sentence (ADR-0006).
        if (error is! GPFailure) Error.throwWithStackTrace(error, stackTrace);
        emit(AccountsState(balances: state.balances, failure: error));
      },
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
