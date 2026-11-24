import 'dart:async';

extension GPStreamExtension<S> on Stream<S> {
  /// Cancels the previous inner stream before starting the next.
  Stream<T> switchMap<T>(Stream<T> Function(S value) convert) {
    final controller = isBroadcast ? StreamController<T>.broadcast(sync: true) : StreamController<T>(sync: true);
    StreamSubscription<S>? outer;
    StreamSubscription<T>? inner;
    var sourceDone = false;

    controller
      ..onListen = () {
        outer = listen(
          (value) {
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

    // A broadcast controller refuses pause callbacks; its listeners pause on their own.
    if (!isBroadcast) {
      controller
        ..onPause = () {
          outer?.pause();
          inner?.pause();
        }
        ..onResume = () {
          outer?.resume();
          inner?.resume();
        };
    }

    return controller.stream;
  }
}
