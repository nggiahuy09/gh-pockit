import 'package:ghpockit/core/utils/clock.dart';

class FakeClock extends GPClock {
  FakeClock([DateTime? start]) : _now = (start ?? DateTime.utc(2026, 9, 9, 12)).toUtc();

  DateTime _now;

  @override
  DateTime nowUtc() => _now;

  @override
  int nowEpochMillis() => _now.millisecondsSinceEpoch;

  void advance(Duration by) {
    assert(!by.isNegative, 'use rewindForTest to move a FakeClock backwards');
    _now = _now.add(by);
  }

  /// Simulates an NTP correction: real device clocks jump backwards.
  void rewindForTest(Duration by) => _now = _now.subtract(by);
}
