import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/bloc/transformers.dart';

late List<String> _log;
late Map<String, StreamController<String>> _inners;

void main() {
  setUp(() {
    _log = <String>[];
    _inners = <String, StreamController<String>>{};
  });

  test('cancels the running inner stream before it listens to the next', () async {
    final source = StreamController<String>();
    final output = <String>[];
    final subscription = restartable<String>().call(source.stream, _innerFor).listen(output.add);
    addTearDown(subscription.cancel);

    source.add('a');
    await pumpEventQueue();
    _inners['a']!.add('a1');
    source.add('b');
    await pumpEventQueue();
    _inners['b']!.add('b1');
    await pumpEventQueue();

    expect(_log, ['listen a', 'cancel a', 'listen b']);
    expect(output, ['a1', 'b1']);
  });

  test("forwards the current inner stream's errors", () async {
    final source = StreamController<String>();
    final errors = <Object>[];
    final subscription = restartable<String>().call(source.stream, _innerFor).listen(null, onError: errors.add);
    addTearDown(subscription.cancel);

    source.add('a');
    await pumpEventQueue();
    _inners['a']!.addError(StateError('a'));
    await pumpEventQueue();

    expect(errors, [isA<StateError>()]);
  });

  test('ends once the source is done and so is the last inner stream', () async {
    final source = StreamController<String>();
    var done = false;
    final subscription = restartable<String>().call(source.stream, _innerFor).listen(null, onDone: () => done = true);
    addTearDown(subscription.cancel);

    source.add('a');
    await pumpEventQueue();
    await source.close();
    await pumpEventQueue();

    expect(done, isFalse);

    await _inners['a']!.close();
    await pumpEventQueue();

    expect(done, isTrue);
  });

  test('cancelling the output cancels the source and the running inner stream', () async {
    var sourceCancelled = false;
    final source = StreamController<String>(onCancel: () => sourceCancelled = true);
    final subscription = restartable<String>().call(source.stream, _innerFor).listen(null);

    source.add('a');
    await pumpEventQueue();
    await subscription.cancel();

    expect(sourceCancelled, isTrue);
    expect(_log, ['listen a', 'cancel a']);
  });

  test('in a bloc, a new event stops the running handler before the next one starts', () async {
    final bloc = _WatchBloc(_innerFor);
    addTearDown(bloc.close);

    bloc.add('a');
    await pumpEventQueue();
    _inners['a']!.add('a1');
    await pumpEventQueue();

    expect(bloc.state, 'a1');

    bloc.add('b');
    await pumpEventQueue();
    _inners['b']!.add('b1');
    await pumpEventQueue();

    expect(_log, ['listen a', 'cancel a', 'listen b']);
    expect(bloc.state, 'b1');
  });
}

final class _WatchBloc extends Bloc<String, String> {
  _WatchBloc(Stream<String> Function(String key) watch) : super('') {
    on<String>((key, emit) => emit.forEach<String>(watch.call(key), onData: (value) => value), transformer: restartable());
  }
}

Stream<String> _innerFor(String event) {
  final controller = StreamController<String>(onListen: () => _log.add('listen $event'), onCancel: () => _log.add('cancel $event'));
  _inners[event] = controller;
  return controller.stream;
}
