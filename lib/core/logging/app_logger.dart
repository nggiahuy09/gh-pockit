import 'package:meta/meta.dart';

import '../utils/clock.dart';
import 'log_redactor.dart';

@immutable
final class GPLogRecord {
  const GPLogRecord({this.fields = const {}, required this.level, this.error, this.stackTrace, required this.timestamp, required this.message});

  /// Already redacted by [GPAppLogger.log].
  final Map<String, Object?> fields;

  final GPLogLevel level;
  final Object? error;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  /// A constant string, never an interpolated payload: [fields] is redacted, a message cannot be.
  final String message;
}

abstract class GPAppLogger {
  const GPAppLogger(GPClock clock) : _clock = clock;

  final GPClock _clock;

  /// The sink. App code calls [log] or a shorthand instead: those redact, so a new sink cannot leak (golden rule 9).
  void write(GPLogRecord record);

  void log(GPLogLevel level, String message, {Map<String, Object?>? fields, Object? error, StackTrace? stackTrace}) =>
      write(GPLogRecord(fields: redactSensitiveFields(fields), level: level, error: error, stackTrace: stackTrace, timestamp: _clock.nowUtc(), message: message));

  void debug(String message, {Map<String, Object?>? fields}) => log(GPLogLevel.debug, message, fields: fields);

  void info(String message, {Map<String, Object?>? fields}) => log(GPLogLevel.info, message, fields: fields);

  void warn(String message, {Map<String, Object?>? fields, Object? error, StackTrace? stackTrace}) =>
      log(GPLogLevel.warn, message, fields: fields, error: error, stackTrace: stackTrace);

  void error(String message, {Map<String, Object?>? fields, Object? error, StackTrace? stackTrace}) =>
      log(GPLogLevel.error, message, fields: fields, error: error, stackTrace: stackTrace);
}

/// In severity order: [isAtLeast] relies on it.
enum GPLogLevel {
  /// Dropped in release builds.
  debug,
  info,
  warn,
  error;

  bool isAtLeast(GPLogLevel minLevel) => index >= minLevel.index;
}
