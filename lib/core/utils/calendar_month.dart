import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// A month of the device's calendar. Its bounds are local midnights, so a range query over it is half-open `[start, end)` (ADR-0009 §6).
@immutable
final class GPCalendarMonth with Equatable {
  /// [month] is 1–12: `(2026, 13)` spans the same days as `(2027, 1)` but is not equal to it.
  const GPCalendarMonth(this.year, this.month) : assert(month >= 1 && month <= 12, 'month must be 1–12');

  /// Takes the month [moment] shows in its own zone: pass a local `DateTime` for the user's month.
  GPCalendarMonth.of(DateTime moment) : year = moment.year, month = moment.month;

  final int year;
  final int month;

  DateTime get start => DateTime(year, month);

  /// `DateTime` rolls month 13 into January of the next year.
  DateTime get end => DateTime(year, month + 1);

  @override
  List<Object?> get props => [year, month];
}
