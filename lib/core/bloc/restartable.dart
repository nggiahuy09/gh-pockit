import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

/// Handles only the latest event: a new one cancels the handler still running for the previous one (ADR-0012).
EventTransformer<E> restartable<E>() => _switchMap;

/// Pause is not forwarded: bloc never pauses its event stream.
Stream<T> _switchMap<S, T>(Stream<S> source, Stream<T> Function(S value) convert) {
  final controller = source.isBroadcast ? StreamController<T>.broadcast(sync: true) : StreamController<T>(sync: true);
  StreamSubscription<S>? outer;
  StreamSubscription<T>? inner;
  var sourceDone = false;

  controller
    ..onListen = () {
      outer = source.listen(
        (value) {
          // Cancel before listening: for a bloc, listening starts the next handler, and the previous one must not emit once it has.
          unawaited(inner?.cancel());
          inner = convert(value).listen(
            controller.add,
            onError: controller.addError,
            onDone: () {
              inner = null;
              if (sourceDone) unawaited(controller.close());
            },
          );
        },
        onError: controller.addError,
        onDone: () {
          sourceDone = true;
          if (inner == null) unawaited(controller.close());
        },
      );
    }
    ..onCancel = () => Future.wait<void>([?outer?.cancel(), ?inner?.cancel()]);

  return controller.stream;
}
