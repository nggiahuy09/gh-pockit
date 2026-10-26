part of 'sample_data_bloc.dart';

@immutable
sealed class SampleDataEvent {
  const SampleDataEvent();
}

/// One expense in the oldest account, creating that account first when there is none.
@immutable
final class SampleDataAddEvent extends SampleDataEvent {
  const SampleDataAddEvent({required this.accountName, required this.note});

  final String accountName;
  final String note;
}

@immutable
final class SampleDataSeedEvent extends SampleDataEvent {
  const SampleDataSeedEvent();
}
