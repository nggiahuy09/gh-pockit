import 'package:ghpockit/core/utils/uuid_generator.dart';

/// A [GPUuidGenerator] that hands out predictable ids.
///
/// The point is not that the ids look like UUIDs — nothing in the app parses one — but that a test can *name* the id a write is about to mint, and then
/// assert on the row it produced. With the real generator the only way to learn the id is to read it back out of the thing under test, which makes the
/// assertion agree with the implementation by construction.
///
/// [v7] and [v4] keep separate counters, so a test can tell an entity key apart from an idempotency key when the outbox lands in W7.
class FakeUuidGenerator extends GPUuidGenerator {
  FakeUuidGenerator({this.prefix = 'id'});

  final String prefix;

  int _v7Count = 0;
  int _v4Count = 0;

  /// Ids handed out by [v7], oldest first — the order a test asserts creation order in.
  final List<String> issuedV7 = <String>[];

  @override
  String v4() => '$prefix-v4-${++_v4Count}';

  @override
  String v7() {
    final id = '$prefix-v7-${++_v7Count}';
    issuedV7.add(id);

    return id;
  }
}
