part of 'home_month_summary_bloc.dart';

@immutable
sealed class HomeMonthSummaryEvent {
  const HomeMonthSummaryEvent();
}

@immutable
final class _HomeMonthSummaryWatchEvent extends HomeMonthSummaryEvent {
  const _HomeMonthSummaryWatchEvent();
}
