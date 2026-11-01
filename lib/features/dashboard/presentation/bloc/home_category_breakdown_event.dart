part of 'home_category_breakdown_bloc.dart';

@immutable
sealed class HomeCategoryBreakdownEvent {
  const HomeCategoryBreakdownEvent();
}

@immutable
final class _HomeCategoryBreakdownWatchEvent extends HomeCategoryBreakdownEvent {
  const _HomeCategoryBreakdownWatchEvent();
}
