import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

import '../../../../app/di/injector.dart';
import '../../../../core/bloc/transformers.dart';
import '../../../../core/domain/use_case.dart';
import '../../../../core/error/failure.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../domain/entities/account_balance.dart';
import '../../domain/usecases/watch_account_balances_use_case.dart';

part 'accounts_event.dart';

part 'accounts_state.dart';

final class AccountsBloc extends Bloc<AccountsEvent, AccountsState> {
  AccountsBloc() : super(const AccountsInitState()) {
    on<AccountsEvent>(_eventHandler, transformer: restartable());

    add(const _AccountsWatchEvent());
  }

  final _watchAccountBalances = WatchAccountBalancesUseCase(getIt.get<TransactionRepository>());

  Future<void> _eventHandler(AccountsEvent event, Emitter<AccountsState> emit) async {
    switch (event) {
      case _AccountsWatchEvent():
        await _watchHandler(emit);
    }
  }

  Future<void> _watchHandler(Emitter<AccountsState> emit) {
    emit(AccountsLoadingState(state.balances));

    return emit.forEach(
      _watchAccountBalances.execute(const GPNoInput()),
      onData: AccountsLoadedState.new,
      onError: (error, stackTrace) {
        // Anything but a `GPFailure` is a bug: rethrown, not shown as a sentence (ADR-0006).
        if (error is! GPFailure) Error.throwWithStackTrace(error, stackTrace);
        return AccountsLoadErrorState(state.balances, error);
      },
    );
  }
}
