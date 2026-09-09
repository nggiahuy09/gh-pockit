import 'package:ghpockit/core/logging/app_logger.dart';

/// An [GPAppLogger] that keeps its records in a list instead of writing them.
///
/// Used to assert *what* the app logs — above all that it does not log what golden rule 9 forbids.
class RecordingLogger extends GPAppLogger {
  RecordingLogger({required super.clock});

  final List<GPLogRecord> records = <GPLogRecord>[];

  GPLogRecord get last => records.last;

  @override
  void write(GPLogRecord record) => records.add(record);
}
