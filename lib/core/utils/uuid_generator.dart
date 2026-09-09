import 'dart:math';
import 'dart:typed_data';

import 'package:ghpockit/core/utils/clock.dart';
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';

/// Generates entity IDs on the client.
///
/// Golden rule 4: an ID is never handed back by the server. The app must be able to create a transaction on a plane, reference it from an outbox
/// mutation and from a receipt row, and only later tell the server about it — so the ID has to exist the moment the row does.
///
/// Two variants, for two different jobs:
///
/// * [v7] for entity primary keys. A v7 UUID leads with a 48-bit millisecond
///   timestamp, so newly created IDs sort after older ones. That keeps SQLite
///   B-tree inserts append-only instead of scattering them across the index,
///   and it gives `ORDER BY occurred_at DESC, id DESC` a tiebreaker that
///   matches creation order.
/// * [v4] for anything that must not carry a timestamp or an order —
///   idempotency keys above all. An idempotency key is only ever compared for
///   equality, and leaking creation time through it buys nothing.
///
/// Wrapped in an interface for the same reason as `GPClock`: a sync test that asserts "the same mutation retried twice keeps one idempotency key" is far
/// easier to write against a generator whose output it controls.
abstract class GPUuidGenerator {
  const GPUuidGenerator();

  /// Random UUID v4. Use for idempotency keys.
  String v4();

  /// Time-ordered UUID v7. Use for entity primary keys.
  String v7();
}

/// Production implementation, backed by `package:uuid`.
///
/// This is the only file allowed to import `package:uuid` — everything else
/// depends on [GPUuidGenerator], so replacing the package later is a one-file change.
///
/// **Must be a singleton.** [v7] keeps a counter across calls (see below); two instances would each run their own and hand out IDs that interleave out of
/// order. `configureCoreDependencies` registers it as a lazy singleton for exactly this reason.
class GPUuidGeneratorImpl extends GPUuidGenerator {
  GPUuidGeneratorImpl({required GPClock clock, Uuid uuid = const Uuid(), Random? random}) : _clock = clock, _uuid = uuid, _random = random ?? Random.secure();

  /// Largest value the 12-bit counter can hold before it has to borrow from the next millisecond.
  static const int _maxCounter = 0xFFF;

  final GPClock _clock;
  final Uuid _uuid;
  final Random _random;

  int _lastMillis = 0;
  int _counter = 0;

  @override
  String v4() => _uuid.v4();

  @override
  String v7() {
    // `package:uuid` fills all 74 free bits of a v7 with randomness, which is
    // RFC 9562 compliant but only orders IDs *between* milliseconds: two IDs
    // created in the same tick sort at random. That is precisely the case a
    // bulk insert or a sync pull hits, so this fills the 12-bit `rand_a`
    // field with a monotonic counter instead — RFC 9562 §6.2 "method 2".
    // `rand_b` stays random, so IDs are still unguessable.
    final now = _clock.nowEpochMillis();

    if (now > _lastMillis) {
      _lastMillis = now;
      _counter = 0;
    } else {
      // Same millisecond — or the wall clock went backwards, which NTP does
      // do. Either way the previous timestamp is kept: an ID must never sort before one already handed out.
      _counter++;
      if (_counter > _maxCounter) {
        // More than 4096 IDs in one millisecond. Borrow from the next one
        // rather than reuse a counter value; the drift is at most 1ms per 4096 IDs and self-corrects as soon as the clock catches up.
        _lastMillis++;
        _counter = 0;
      }
    }

    final randomBytes = Uint8List(10);
    // Bytes 0-1 become `rand_a`. The high nibble of byte 0 is overwritten with
    // the version, so only its low nibble is ours: 4 + 8 = 12 counter bits.
    randomBytes[0] = (_counter >> 8) & 0x0F;
    randomBytes[1] = _counter & 0xFF;
    for (var i = 2; i < randomBytes.length; i++) {
      randomBytes[i] = _random.nextInt(256);
    }

    return _uuid.v7(config: V7Options(_lastMillis, randomBytes));
  }
}
