part of 'sample_data_bloc.dart';

@immutable
sealed class SampleDataState with Equatable {
  const SampleDataState();

  @override
  List<Object?> get props => const [];
}

final class SampleDataInitState extends SampleDataState {
  const SampleDataInitState();
}

sealed class SampleDataLoadingState extends SampleDataState {
  const SampleDataLoadingState();
}

final class SampleDataAddLoadingState extends SampleDataLoadingState {
  const SampleDataAddLoadingState();
}

final class SampleDataSeedLoadingState extends SampleDataLoadingState {
  const SampleDataSeedLoadingState();
}

/// What the view reports in a snackbar.
sealed class SampleDataOutcomeState extends SampleDataState {
  const SampleDataOutcomeState();
}

final class SampleDataAddedState extends SampleDataOutcomeState {
  const SampleDataAddedState();
}

final class SampleDataAddErrorState extends SampleDataOutcomeState {
  const SampleDataAddErrorState(this.failure);

  final GPFailure failure;

  @override
  List<Object?> get props => [failure];
}

final class SampleDataSeededState extends SampleDataOutcomeState {
  const SampleDataSeededState(this.count);

  /// How many transactions were written.
  final int count;

  @override
  List<Object?> get props => [count];
}

final class SampleDataSeedErrorState extends SampleDataOutcomeState {
  const SampleDataSeedErrorState(this.failure);

  final GPFailure failure;

  @override
  List<Object?> get props => [failure];
}
