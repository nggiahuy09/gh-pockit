import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/bloc/restartable.dart';

void main() {
  late List<String> log;
  late Map<String, StreamController<String>> inners;

  setUp(() {
    log = <String>[];
    inners = <String, StreamController<String>>{};
  });

  Stream<String> innerFor(String event) {
    final controller = StreamController<String>(onListen: () => log.add('listen $event'), onCancel: () => log.add('cancel $event'));
    inners[event] = controller;
    return controller.stream;
  }

  test('cancels the running inner stream before it listens to the next', () async {
    final source = StreamController<String>();
    final output = <String>[];
    final subscription = restartable<String>()(source.stream, innerFor).listen(output.add);
    addTearDown(subscription.cancel);

    source.add('a');
    await pumpEventQueue();
    inners['a']!.add('a1');
    source.add('b');
    await pumpEventQueue();
    inners['b']!.add('b1');
    await pumpEventQueue();

    expect(log, ['listen a', 'cancel a', 'listen b']);
    expect(output, ['a1', 'b1']);
  });

  test("forwards the current inner stream's errors", () async {
    final source = StreamController<String>();
    final errors = <Object>[];
    final subscription = restartable<String>()(source.stream, innerFor).listen(null, onError: errors.add);
    addTearDown(subscription.cancel);

    source.add('a');
    await pumpEventQueue();
    inners['a']!.addError(StateError('a'));
    await pumpEventQueue();

    expect(errors, [isA<StateError>()]);
  });

  test('ends once the source is done and so is the last inner stream', () async {
    final source = StreamController<String>();
    var done = false;
    final subscription = restartable<String>()(source.stream, innerFor).listen(null, onDone: () => done = true);
    addTearDown(subscription.cancel);

    source.add('a');
    await pumpEventQueue();
    await source.close();
    await pumpEventQueue();

    expect(done, isFalse);

    await inners['a']!.close();
    await pumpEventQueue();

    expect(done, isTrue);
  });

  test('cancelling the output cancels the source and the running inner stream', () async {
    var sourceCancelled = false;
    final source = StreamController<String>(onCancel: () => sourceCancelled = true);
    final subscription = restartable<String>()(source.stream, innerFor).listen(null);

    source.add('a');
    await pumpEventQueue();
    await subscription.cancel();

    expect(sourceCancelled, isTrue);
    expect(log, ['listen a', 'cancel a']);
  });

  test('in a bloc, a new event stops the running handler before the next one starts', () async {
    final bloc = _WatchBloc(innerFor);
    addTearDown(bloc.close);

    bloc.add('a');
    await pumpEventQueue();
    inners['a']!.add('a1');
    await pumpEventQueue();

    expect(bloc.state, 'a1');

    bloc.add('b');
    await pumpEventQueue();
    inners['b']!.add('b1');
    await pumpEventQueue();

    expect(log, ['listen a', 'cancel a', 'listen b']);
    expect(bloc.state, 'b1');
  });
}

class _WatchBloc extends Bloc<String, String> {
  _WatchBloc(Stream<String> Function(String key) watch) : super('') {
    on<String>((key, emit) => emit.forEach<String>(watch(key), onData: (value) => value), transformer: restartable());
  }
}
