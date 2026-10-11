import 'package:ghpockit/core/logging/log_redactor.dart';
import 'package:ghpockit/core/utils/clock.dart';

enum GPLogLevel {
  /// Dropped in release builds.
  debug,
  info,
  warn,
  error;

  /// Relies on declaration order: keep the constants ordered by severity.
  bool isAtLeast(GPLogLevel minLevel) => index >= minLevel.index;
}

class GPLogRecord {
  const GPLogRecord({
    required this.level,
    required this.timestamp,
    required this.message,
    this.fields = const {},
    this.error,
    this.stackTrace,
  });

  final GPLogLevel level;
  final DateTime timestamp;

  /// A constant string, never an interpolated payload: [fields] is redacted, a message cannot be.
  final String message;

  /// Already redacted by [GPAppLogger.log].
  final Map<String, Object?> fields;

  final Object? error;
  final StackTrace? stackTrace;
}

abstract class GPAppLogger {
  const GPAppLogger({required GPClock clock}) : _clock = clock;

  final GPClock _clock;

  /// The sink. App code calls [log] or a shorthand instead: those redact, so a new sink cannot leak (golden rule 9).
  void write(GPLogRecord record);

  void log(GPLogLevel level, String message, {Map<String, Object?>? fields, Object? error, StackTrace? stackTrace}) {
    write(
      GPLogRecord(
        level: level,
        timestamp: _clock.nowUtc(),
        message: message,
        fields: redactSensitiveFields(fields),
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  void debug(String message, {Map<String, Object?>? fields}) => log(GPLogLevel.debug, message, fields: fields);

  void info(String message, {Map<String, Object?>? fields}) => log(GPLogLevel.info, message, fields: fields);

  void warn(String message, {Map<String, Object?>? fields, Object? error, StackTrace? stackTrace}) =>
      log(GPLogLevel.warn, message, fields: fields, error: error, stackTrace: stackTrace);

  void error(String message, {Map<String, Object?>? fields, Object? error, StackTrace? stackTrace}) =>
      log(GPLogLevel.error, message, fields: fields, error: error, stackTrace: stackTrace);
}
