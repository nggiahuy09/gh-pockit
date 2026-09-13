import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/utils/clock.dart';

import '../../helpers/fake_clock.dart';

void main() {
  group('GPSystemClock', () {
    const clock = GPSystemClock();

    test('nowUtc is always UTC', () {
      expect(clock.nowUtc().isUtc, isTrue);
    });

    test('nowUtc and nowEpochMillis agree', () {
      final before = clock.nowUtc();
      final millis = clock.nowEpochMillis();
      final after = clock.nowUtc();

      expect(millis, greaterThanOrEqualTo(before.millisecondsSinceEpoch));
      expect(millis, lessThanOrEqualTo(after.millisecondsSinceEpoch));
    });

    test('does not go backwards across reads', () {
      final first = clock.nowEpochMillis();
      final second = clock.nowEpochMillis();

      expect(second, greaterThanOrEqualTo(first));
    });
  });

  group('FakeClock', () {
    test('stands still until advanced', () {
      final clock = FakeClock(DateTime.utc(2026, 9, 9, 12));

      expect(clock.nowUtc(), DateTime.utc(2026, 9, 9, 12));
      expect(clock.nowUtc(), clock.nowUtc());

      clock.advance(const Duration(minutes: 90));

      expect(clock.nowUtc(), DateTime.utc(2026, 9, 9, 13, 30));
    });

    test('normalises a local start instant to UTC', () {
      final clock = FakeClock(DateTime(2026, 9, 9, 12));

      expect(clock.nowUtc().isUtc, isTrue);
      expect(clock.nowEpochMillis(), DateTime(2026, 9, 9, 12).millisecondsSinceEpoch);
    });
  });
}
