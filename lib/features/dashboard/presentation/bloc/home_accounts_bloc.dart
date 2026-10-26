import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

import '../../../../app/di/injector.dart';
import '../../../../core/bloc/transformers.dart';
import '../../../../core/domain/use_case.dart';
import '../../../../core/error/failure.dart';
import '../../../accounts/domain/entities/account_balance.dart';
import '../../../accounts/domain/usecases/watch_account_balances_use_case.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';

part 'home_accounts_event.dart';

part 'home_accounts_state.dart';

/// The accounts section of Home, the same balances the Accounts tab shows (ADR-0013).
final class HomeAccountsBloc extends Bloc<HomeAccountsEvent, HomeAccountsState> {
  HomeAccountsBloc() : super(const HomeAccountsInitState()) {
    on<HomeAccountsEvent>(_eventHandler, transformer: restartable());

    add(const _HomeAccountsWatchEvent());
  }

  final _watchAccountBalances = WatchAccountBalancesUseCase(getIt.get<TransactionRepository>());

  Future<void> _eventHandler(HomeAccountsEvent event, Emitter<HomeAccountsState> emit) async {
    switch (event) {
      case _HomeAccountsWatchEvent():
        await _watchHandler(emit);
    }
  }

  Future<void> _watchHandler(Emitter<HomeAccountsState> emit) {
    emit(HomeAccountsLoadingState(state.accounts));

    return emit.forEach(
      _watchAccountBalances.execute(const GPNoInput()),
      onData: HomeAccountsLoadedState.new,
      onError: (error, stackTrace) {
        // Anything but a `GPFailure` is a bug: rethrown, not shown as a sentence (ADR-0006).
        if (error is! GPFailure) Error.throwWithStackTrace(error, stackTrace);
        return HomeAccountsLoadErrorState(state.accounts, error);
      },
    );
  }
}
