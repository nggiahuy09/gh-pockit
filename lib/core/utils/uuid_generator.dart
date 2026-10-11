import 'dart:math';
import 'dart:typed_data';

import 'package:ghpockit/core/utils/clock.dart';
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';

abstract class GPUuidGenerator {
  const GPUuidGenerator();

  /// For idempotency keys: random, so it leaks no creation time.
  String v4();

  /// For entity primary keys: time-ordered, so inserts append to the index and `id` breaks `occurred_at` ties in creation order.
  String v7();

  /// Deterministic, only for rows every device seeds (ADR-0002). [name] must hold all that makes the row unique, e.g. owner + key for a category.
  String v5(String name);
}

/// Must be a singleton: [v7]'s counter lives in the instance, so two instances would interleave ids out of order.
class GPUuidGeneratorImpl extends GPUuidGenerator {
  GPUuidGeneratorImpl({required GPClock clock, Uuid uuid = const Uuid(), Random? random}) : _clock = clock, _uuid = uuid, _random = random ?? Random.secure();

  static const int _maxCounter = 0xFFF;

  final GPClock _clock;
  final Uuid _uuid;
  final Random _random;

  int _lastMillis = 0;
  int _counter = 0;

  /// Frozen: changing it changes every derived id, which after a release is a data migration.
  static const String namespace = '6f3c1e6a-2f5f-4f4e-9f2a-0e2c9a8b7d41';

  @override
  String v4() => _uuid.v4();

  @override
  String v5(String name) => _uuid.v5(namespace, name);

  @override
  String v7() {
    // `package:uuid` randomises `rand_a` too, so ids from one millisecond would sort at random. A 12-bit counter there keeps them in order
    // (RFC 9562 §6.2, method 2); `rand_b` stays random.
    final now = _clock.nowEpochMillis();

    if (now > _lastMillis) {
      _lastMillis = now;
      _counter = 0;
    } else {
      // Same millisecond, or the clock went backwards (NTP): keep the last timestamp so no id sorts before one already issued.
      _counter++;
      if (_counter > _maxCounter) {
        // Over 4096 ids in one millisecond: borrow the next one. The drift self-corrects once the clock catches up.
        _lastMillis++;
        _counter = 0;
      }
    }

    final randomBytes = Uint8List(10);
    // Bytes 0–1 become `rand_a`; the version overwrites byte 0's high nibble, leaving 4 + 8 = 12 counter bits.
    randomBytes[0] = (_counter >> 8) & 0x0F;
    randomBytes[1] = _counter & 0xFF;
    for (var i = 2; i < randomBytes.length; i++) {
      randomBytes[i] = _random.nextInt(256);
    }

    return _uuid.v7(config: V7Options(_lastMillis, randomBytes));
  }
}
