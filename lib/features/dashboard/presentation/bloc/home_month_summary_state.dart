part of 'home_month_summary_bloc.dart';

@immutable
sealed class HomeMonthSummaryState with Equatable {
  const HomeMonthSummaryState(this.totals);

  /// Null until the first totals arrive.
  final IncomeExpenseTotals? totals;

  @override
  List<Object?> get props => [totals];
}

final class HomeMonthSummaryInitState extends HomeMonthSummaryState {
  const HomeMonthSummaryInitState() : super(null);
}

final class HomeMonthSummaryLoadingState extends HomeMonthSummaryState {
  const HomeMonthSummaryLoadingState(super.totals);
}

final class HomeMonthSummaryLoadedState extends HomeMonthSummaryState {
  const HomeMonthSummaryLoadedState(IncomeExpenseTotals super.totals);

  @override
  IncomeExpenseTotals get totals => super.totals!;
}

/// Keeps the last totals: the stream stays live, so the card recovers by itself.
final class HomeMonthSummaryLoadErrorState extends HomeMonthSummaryState {
  const HomeMonthSummaryLoadErrorState(super.totals, this.failure);

  final GPFailure failure;

  @override
  List<Object?> get props => [...super.props, failure];
}
