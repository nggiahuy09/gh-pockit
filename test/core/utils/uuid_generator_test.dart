import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/utils/uuid_generator.dart';

import '../../helpers/fake_clock.dart';

void main() {
  // Version nibble and RFC 9562 variant bits pinned: plain random hex would pass a looser pattern.
  RegExp canonical(int version) => RegExp('^[0-9a-f]{8}-[0-9a-f]{4}-$version[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\$');

  int timestampOf(String id) => int.parse(id.substring(0, 8) + id.substring(9, 13), radix: 16);

  group('v4', () {
    test('is a canonical version-4 UUID', () {
      expect(GPUuidGeneratorImpl(clock: FakeClock()).v4(), matches(canonical(4)));
    });

    test('does not repeat', () {
      final generator = GPUuidGeneratorImpl(clock: FakeClock());
      final ids = {for (var i = 0; i < 1000; i++) generator.v4()};

      expect(ids, hasLength(1000));
    });

    test('carries no timestamp — an idempotency key must not leak one', () {
      // The 48 bits that hold a v7's timestamp must not hold the clock in a v4.
      final clock = FakeClock(DateTime.utc(2026, 9, 9, 21, 30));

      expect(timestampOf(GPUuidGeneratorImpl(clock: clock).v4()), isNot(clock.nowEpochMillis()));
    });
  });

  group('v7', () {
    test('is a canonical version-7 UUID', () {
      expect(GPUuidGeneratorImpl(clock: FakeClock()).v7(), matches(canonical(7)));
    });

    test('does not repeat', () {
      final generator = GPUuidGeneratorImpl(clock: FakeClock());
      final ids = {for (var i = 0; i < 1000; i++) generator.v7()};

      expect(ids, hasLength(1000));
    });

    test('encodes the clock in its 48-bit prefix', () {
      final clock = FakeClock(DateTime.utc(2026, 9, 9, 21, 30));

      expect(timestampOf(GPUuidGeneratorImpl(clock: clock).v7()), clock.nowEpochMillis());
    });

    test('sorts in creation order within one millisecond', () {
      // The clock never moves, so order can only come from the monotonic counter — what `package:uuid` alone gets wrong.
      final generator = GPUuidGeneratorImpl(clock: FakeClock());
      final ids = [for (var i = 0; i < 500; i++) generator.v7()];

      expect(ids, [...ids]..sort());
    });

    test('sorts in creation order across milliseconds', () {
      final clock = FakeClock();
      final generator = GPUuidGeneratorImpl(clock: clock);
      final ids = <String>[];

      for (var i = 0; i < 50; i++) {
        ids.add(generator.v7());
        clock.advance(const Duration(milliseconds: 1));
      }

      expect(ids, [...ids]..sort());
    });

    test('stays ordered when the wall clock jumps backwards', () {
      // An NTP correction mid-session: ids must still sort in issue order, or the `id DESC` tie-break lies.
      final clock = FakeClock(DateTime.utc(2026, 9, 9, 21, 30));
      final generator = GPUuidGeneratorImpl(clock: clock);

      final before = generator.v7();
      clock.rewindForTest(const Duration(minutes: 5));
      final after = generator.v7();

      expect(after.compareTo(before), greaterThan(0));
      expect(timestampOf(after), timestampOf(before));
    });

    test('borrows the next millisecond when the counter overflows', () {
      // 4096 ids exhaust the 12-bit counter; the 4097th advances the timestamp instead of reusing a value.
      final clock = FakeClock(DateTime.utc(2026, 9, 9, 21, 30));
      final generator = GPUuidGeneratorImpl(clock: clock);
      final ids = [for (var i = 0; i < 4097; i++) generator.v7()];

      expect(ids.toSet(), hasLength(4097));
      expect(ids, [...ids]..sort());
      expect(timestampOf(ids[4095]), clock.nowEpochMillis());
      expect(timestampOf(ids[4096]), clock.nowEpochMillis() + 1);
    });
  });

  group('v5', () {
    // The opposite of v4/v7: two devices must derive the same id without talking (the category seeder).
    test('returns the same id for the same name, every time and on every instance', () {
      final first = GPUuidGeneratorImpl(clock: FakeClock());
      final second = GPUuidGeneratorImpl(clock: FakeClock(DateTime.utc(2030)));

      expect(first.v5('local|category.food'), first.v5('local|category.food'));
      expect(second.v5('local|category.food'), first.v5('local|category.food'));
    });

    test('returns different ids for different names', () {
      final generator = GPUuidGeneratorImpl(clock: FakeClock());

      expect(generator.v5('local|category.food'), isNot(generator.v5('local|category.bills')));
      // The owner half matters as much as the key: without it every user would share one set of category ids.
      expect(generator.v5('local|category.food'), isNot(generator.v5('someone-else|category.food')));
    });

    test('is a well-formed v5 UUID', () {
      // A server column typed `uuid` (W10) will parse these.
      final id = GPUuidGeneratorImpl(clock: FakeClock()).v5('local|category.food');

      expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    });

    test('carries no timestamp, so it cannot be mistaken for a v7', () {
      final clock = FakeClock();
      final generator = GPUuidGeneratorImpl(clock: clock);

      expect(generator.v5('local|category.food'), isNot(generator.v7()));
    });
  });
}
