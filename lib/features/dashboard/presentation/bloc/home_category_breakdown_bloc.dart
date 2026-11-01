import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

import '../../../../app/di/injector.dart';
import '../../../../core/bloc/transformers.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/calendar_month.dart';
import '../../../transactions/domain/entities/category_spending.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../../transactions/domain/usecases/watch_category_breakdown_use_case.dart';

part 'home_category_breakdown_event.dart';

part 'home_category_breakdown_state.dart';

/// Home's spending by category, apart from the month card so either can fail alone. [month] is fixed as in `HomeMonthSummaryBloc`.
final class HomeCategoryBreakdownBloc extends Bloc<HomeCategoryBreakdownEvent, HomeCategoryBreakdownState> {
  HomeCategoryBreakdownBloc(this.month) : super(const HomeCategoryBreakdownInitState()) {
    on<HomeCategoryBreakdownEvent>(_eventHandler, transformer: restartable());

    add(const _HomeCategoryBreakdownWatchEvent());
  }

  final GPCalendarMonth month;

  final _watchCategoryBreakdown = WatchCategoryBreakdownUseCase(getIt.get<TransactionRepository>());

  Future<void> _eventHandler(HomeCategoryBreakdownEvent event, Emitter<HomeCategoryBreakdownState> emit) async {
    switch (event) {
      case _HomeCategoryBreakdownWatchEvent():
        await _watchHandler(emit);
    }
  }

  Future<void> _watchHandler(Emitter<HomeCategoryBreakdownState> emit) {
    emit(HomeCategoryBreakdownLoadingState(state.breakdown));

    return emit.forEach(
      _watchCategoryBreakdown.execute(WatchCategoryBreakdownInput(month)),
      onData: HomeCategoryBreakdownLoadedState.new,
      onError: (error, stackTrace) {
        // Anything but a `GPFailure` is a bug: rethrown, not shown as a sentence (ADR-0006).
        if (error is! GPFailure) Error.throwWithStackTrace(error, stackTrace);
        return HomeCategoryBreakdownLoadErrorState(state.breakdown, error);
      },
    );
  }
}
