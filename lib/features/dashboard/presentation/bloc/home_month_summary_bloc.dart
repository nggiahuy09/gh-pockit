import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

import '../../../../app/di/injector.dart';
import '../../../../core/bloc/transformers.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/calendar_month.dart';
import '../../../transactions/domain/entities/income_expense_totals.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../../transactions/domain/usecases/watch_monthly_summary_use_case.dart';

part 'home_month_summary_event.dart';

part 'home_month_summary_state.dart';

/// Home's month card. [month] is fixed for the bloc's life, so an app left open past a month's end shows the old one until Home is rebuilt (ADR-0021).
final class HomeMonthSummaryBloc extends Bloc<HomeMonthSummaryEvent, HomeMonthSummaryState> {
  HomeMonthSummaryBloc(this.month) : super(const HomeMonthSummaryInitState()) {
    on<HomeMonthSummaryEvent>(_eventHandler, transformer: restartable());

    add(const _HomeMonthSummaryWatchEvent());
  }

  final GPCalendarMonth month;

  final _watchMonthlySummary = WatchMonthlySummaryUseCase(getIt.get<TransactionRepository>());

  Future<void> _eventHandler(HomeMonthSummaryEvent event, Emitter<HomeMonthSummaryState> emit) async {
    switch (event) {
      case _HomeMonthSummaryWatchEvent():
        await _watchHandler(emit);
    }
  }

  Future<void> _watchHandler(Emitter<HomeMonthSummaryState> emit) {
    emit(HomeMonthSummaryLoadingState(state.totals));

    return emit.forEach(
      _watchMonthlySummary.execute(WatchMonthlySummaryInput(month)),
      onData: HomeMonthSummaryLoadedState.new,
      onError: (error, stackTrace) {
        // Anything but a `GPFailure` is a bug: rethrown, not shown as a sentence (ADR-0006).
        if (error is! GPFailure) Error.throwWithStackTrace(error, stackTrace);
        return HomeMonthSummaryLoadErrorState(state.totals, error);
      },
    );
  }
}
