import '../../../../core/error/failure.dart';
import '../../../../core/utils/clock.dart';

/// ADR-0022: null when [occurredAt] falls on today or earlier in the device's calendar. The day, not the instant: an edit keeps its time of day, so a
/// transaction moved to today may sit hours ahead of now.
GPFailure? refusalFromOccurredAt(DateTime occurredAt, {required GPClock clock}) {
  final today = clock.nowUtc().toLocal();
  // Through the constructor, not `add`: across a DST change a day is not 24 hours long.
  final tomorrow = DateTime(today.year, today.month, today.day + 1);

  return occurredAt.isBefore(tomorrow) ? null : const GPValidationFailure(GPValidationCode.transactionDateInFuture);
}
