import 'dart:developer' as developer;

import 'package:ghpockit/core/logging/app_logger.dart';

/// The low-level call [GPDeveloperLogger] emits through.
///
/// Matches `dart:developer`'s `log()` so its tear-off is the default. The indirection exists only so a test can see what would have been emitted —
/// the developer log itself cannot be read back from a test process.
typedef GPLogSink =
    void Function(
      String message, {
      DateTime? time,
      String name,
      int level,
      Object? error,
      StackTrace? stackTrace,
    });

/// Writes records to the Dart VM's developer log.
///
/// `dart:developer`'s `log()` rather than `print()`: it carries level, error and stack trace as real fields, it shows up structured in DevTools, and
/// `avoid_print` is an analyzer *error* in this repo anyway (`analysis_options.yaml`).
///
/// This is the whole logging backend for now. When `sentry_flutter` lands in P7 it becomes a second [GPAppLogger] beside this one rather than a rewrite of it.
class GPDeveloperLogger extends GPAppLogger {
  const GPDeveloperLogger({required super.clock, this.minLevel = GPLogLevel.info, GPLogSink sink = developer.log}) : _sink = sink;

  /// Records below this level are dropped. Defaults to `info`: the noisy, leak-prone level is the one that has to be opted into, so a logger
  /// constructed without thinking about it behaves like a release build. DI lowers it to `debug` in debug builds.
  final GPLogLevel minLevel;

  final GPLogSink _sink;

  @override
  void write(GPLogRecord record) {
    if (!record.level.isAtLeast(minLevel)) return;

    _sink(
      record.fields.isEmpty ? record.message : '${record.message} ${record.fields}',
      time: record.timestamp,
      name: 'pockit.${record.level.name}',
      level: _developerLevel(record.level),
      error: record.error,
      stackTrace: record.stackTrace,
    );
  }

  /// Maps to the numeric levels `dart:developer` shares with `package:logging`, which is what DevTools filters on.
  int _developerLevel(GPLogLevel level) => switch (level) {
    GPLogLevel.debug => 500,
    GPLogLevel.info => 800,
    GPLogLevel.warn => 900,
    GPLogLevel.error => 1000,
  };
}
