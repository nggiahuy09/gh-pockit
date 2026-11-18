import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/extensions/stream_extension.dart';

void main() {
  test('each value replaces the previous inner stream, which never emits again', () async {
    final source = StreamController<String>();
    final inners = {'a': StreamController<int>(), 'b': StreamController<int>()};
    final seen = <int>[];
    final subscription = source.stream.switchMap((key) => inners[key]!.stream).listen(seen.add);
    addTearDown(subscription.cancel);

    source.add('a');
    await pumpEventQueue();
    inners['a']!.add(1);
    source.add('b');
    await pumpEventQueue();
    inners['a']!.add(2);
    inners['b']!.add(3);
    await pumpEventQueue();

    expect(seen, [1, 3]);
    expect(inners['a']!.hasListener, isFalse);
  });

  test('cancelling cancels the inner stream too', () async {
    final inner = StreamController<int>();
    final subscription = Stream.value('a').switchMap((_) => inner.stream).listen((_) {});
    await pumpEventQueue();
    expect(inner.hasListener, isTrue);

    await subscription.cancel();

    expect(inner.hasListener, isFalse);
  });

  test('a broadcast source gives a broadcast stream', () {
    final source = StreamController<int>.broadcast();
    addTearDown(source.close);

    expect(source.stream.switchMap(Stream.value).isBroadcast, isTrue);
  });
}
