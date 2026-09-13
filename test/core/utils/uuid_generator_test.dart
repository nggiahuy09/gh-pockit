import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/utils/uuid_generator.dart';

import '../../helpers/fake_clock.dart';

void main() {
  // 8-4-4-4-12 hex with the version nibble and the RFC 9562 variant bits
  // ('8'..'b') pinned — a generator that returned plain random hex would pass
  // a looser pattern.
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
      // Nothing about the clock may reach a v4. Read the same 48 bits that
      // hold the timestamp in a v7 and they must not be the current time.
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
      // The clock never moves, so ordering here can only come from the
      // monotonic counter — this is the case `package:uuid` alone gets wrong
      // and the reason entity keys can be sorted at all.
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
      // NTP correction mid-session. An ID handed out after the jump must not
      // sort before one handed out before it, or the tiebreaker in
      // `ORDER BY occurred_at DESC, id DESC` starts lying.
      final clock = FakeClock(DateTime.utc(2026, 9, 9, 21, 30));
      final generator = GPUuidGeneratorImpl(clock: clock);

      final before = generator.v7();
      clock.rewindForTest(const Duration(minutes: 5));
      final after = generator.v7();

      expect(after.compareTo(before), greaterThan(0));
      expect(timestampOf(after), timestampOf(before));
    });

    test('borrows the next millisecond when the counter overflows', () {
      // 4096 IDs is the whole 12-bit counter; the 4097th cannot reuse a value
      // without breaking ordering, so it advances the timestamp instead.
      final clock = FakeClock(DateTime.utc(2026, 9, 9, 21, 30));
      final generator = GPUuidGeneratorImpl(clock: clock);
      final ids = [for (var i = 0; i < 4097; i++) generator.v7()];

      expect(ids.toSet(), hasLength(4097));
      expect(ids, [...ids]..sort());
      expect(timestampOf(ids[4095]), clock.nowEpochMillis());
      expect(timestampOf(ids[4096]), clock.nowEpochMillis() + 1);
    });
  });
}
