import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/utils/calendar_month.dart';

void main() {
  test('spans local midnight on the first to local midnight on the next first', () {
    const october = GPCalendarMonth(2026, 10);

    expect(october.start, DateTime(2026, 10));
    expect(october.end, DateTime(2026, 11));
    expect(october.start.isUtc, isFalse);
  });

  test('December ends on January 1st of the next year', () {
    expect(const GPCalendarMonth(2026, 12).end, DateTime(2027));
  });

  test('refuses a month outside 1–12, which would span the right days but compare unequal', () {
    expect(() => GPCalendarMonth(2026, 0), throwsAssertionError);
    expect(() => GPCalendarMonth(2026, 13), throwsAssertionError);
  });

  test('of() takes the month a moment shows in its own zone', () {
    expect(GPCalendarMonth.of(DateTime(2026, 11, 30, 23, 59)), const GPCalendarMonth(2026, 11));
    expect(GPCalendarMonth.of(DateTime.utc(2026, 12, 31, 23, 59)), const GPCalendarMonth(2026, 12));
  });
}
