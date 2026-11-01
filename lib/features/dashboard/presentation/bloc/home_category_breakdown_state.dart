part of 'home_category_breakdown_bloc.dart';

@immutable
sealed class HomeCategoryBreakdownState with Equatable {
  const HomeCategoryBreakdownState(List<CategorySpending>? breakdown) : _breakdown = breakdown;

  final List<CategorySpending>? _breakdown;

  /// Null until the first breakdown arrives.
  List<CategorySpending>? get breakdown {
    final breakdown = _breakdown;
    return breakdown == null ? null : List.unmodifiable(breakdown);
  }

  @override
  List<Object?> get props => [_breakdown];
}

final class HomeCategoryBreakdownInitState extends HomeCategoryBreakdownState {
  const HomeCategoryBreakdownInitState() : super(null);
}

final class HomeCategoryBreakdownLoadingState extends HomeCategoryBreakdownState {
  const HomeCategoryBreakdownLoadingState(super.breakdown);
}

final class HomeCategoryBreakdownLoadedState extends HomeCategoryBreakdownState {
  const HomeCategoryBreakdownLoadedState(List<CategorySpending> super.breakdown);

  @override
  List<CategorySpending> get breakdown => List.unmodifiable(_breakdown!);
}

/// Keeps the last breakdown: the stream stays live, so the section recovers by itself.
final class HomeCategoryBreakdownLoadErrorState extends HomeCategoryBreakdownState {
  const HomeCategoryBreakdownLoadErrorState(super.breakdown, this.failure);

  final GPFailure failure;

  @override
  List<Object?> get props => [...super.props, failure];
}
