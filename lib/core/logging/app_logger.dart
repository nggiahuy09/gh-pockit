import 'package:ghpockit/core/logging/log_redactor.dart';
import 'package:ghpockit/core/utils/clock.dart';

/// Severity of a log record.
///
/// Deliberately four levels, not seven. More levels only shifts the work from "should I log this" to "at which of the seven levels", and nobody ever
/// filters on `verbose` vs `trace`.
enum GPLogLevel {
  /// Development detail. Dropped in release builds.
  debug,

  /// Something worth seeing in a bug report: a sync cycle started, a mutation was pushed.
  info,

  /// Recovered from, but suspicious: a retryable failure, a conflict.
  warn,

  /// Broke, and the user or the data is affected.
  error;

  /// True when a record at this level passes a `minLevel` filter. Relies on the declaration order above, so keep the constants ordered by severity.
  bool isAtLeast(GPLogLevel minLevel) => index >= minLevel.index;
}

/// One log line, after redaction.
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

  /// Comes from the injected `GPClock`, never from `DateTime.now()`, so a test can assert on the exact value.
  final DateTime timestamp;

  /// A short, roughly constant string — `'sync cycle started'`. Never an interpolated payload: [fields] is redacted, a message string cannot be.
  final String message;

  /// Structured context: `{'entity': 'transaction', 'id': '...'}`. Already passed through [redactSensitiveFields] by [GPAppLogger.log].
  final Map<String, Object?> fields;

  final Object? error;
  final StackTrace? stackTrace;
}

/// Logging entry point for the whole app.
///
/// Subclasses implement [write] (where the record goes: developer console, Sentry, a test list) and inherit [log] and its four shorthands. That split
/// is the point: redaction happens in [log], which is *not* overridable in practice, so a sink added in six months cannot forget golden rule 9. A
/// logger that only enforced its rules by convention would stop enforcing them the day someone is in a hurry.
abstract class GPAppLogger {
  const GPAppLogger({required GPClock clock}) : _clock = clock;

  final GPClock _clock;

  /// Sink hook. Implementations must not be called directly by app code — use [log] or its shorthands, which are the ones that redact.
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
