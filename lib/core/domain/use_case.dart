import 'package:meta/meta.dart';

import '../error/result.dart';
import 'loggable.dart';

mixin GPUseCase<Input extends GPLoggable, Output> {
  Future<GPResult<Output>> execute(Input input);
}

/// Failures arrive on the stream's error channel as a `GPFailure`; anything else there is a bug.
mixin GPStreamUseCase<Input extends GPLoggable, Output> {
  Stream<Output> execute(Input input);
}

@immutable
final class GPNoInput implements GPLoggable {
  const GPNoInput();

  @override
  Map<String, Object?> toLog() => const {};
}
