import 'package:ghpockit/core/utils/clock.dart';

/// A clock that only moves when a test moves it.
///
/// This is the piece that lets sync tests assert on backoff without
/// `Future.delayed` (CLAUDE.md §8): set a start instant, [advance] past the
/// next attempt window, assert the mutation is picked up.
class FakeClock extends GPClock {
  FakeClock([DateTime? start]) : _now = (start ?? DateTime.utc(2026, 9, 9, 12)).toUtc();

  DateTime _now;

  @override
  DateTime nowUtc() => _now;

  @override
  int nowEpochMillis() => _now.millisecondsSinceEpoch;

  /// Moves time forward. Never backwards — that is what [rewindForTest] is
  /// for, and making it explicit keeps an accidental negative [Duration] from
  /// silently turning a test into a clock-skew test.
  void advance(Duration by) {
    assert(!by.isNegative, 'use rewindForTest to move a FakeClock backwards');
    _now = _now.add(by);
  }

  /// Moves time backwards, to simulate an NTP correction. Real device clocks
  /// do this, and anything that assumes "now is never earlier than last time"
  /// has to survive it.
  void rewindForTest(Duration by) => _now = _now.subtract(by);
}
