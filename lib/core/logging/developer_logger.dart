import 'dart:developer' as developer;

import 'package:ghpockit/core/logging/app_logger.dart';

/// `developer.log`'s shape, injectable because a test cannot read the developer log back.
typedef GPLogSink =
    void Function(
      String message, {
      DateTime? time,
      String name,
      int level,
      Object? error,
      StackTrace? stackTrace,
    });

class GPDeveloperLogger extends GPAppLogger {
  const GPDeveloperLogger({required super.clock, this.minLevel = GPLogLevel.info, GPLogSink sink = developer.log}) : _sink = sink;

  /// The default behaves like release; DI lowers it to `debug` in debug builds.
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

  /// `package:logging`'s FINE, INFO, WARNING and SEVERE, which DevTools filters on.
  int _developerLevel(GPLogLevel level) => switch (level) {
    GPLogLevel.debug => 500,
    GPLogLevel.info => 800,
    GPLogLevel.warn => 900,
    GPLogLevel.error => 1000,
  };
}
