import 'package:ghpockit/core/logging/app_logger.dart';

class RecordingLogger extends GPAppLogger {
  RecordingLogger({required super.clock});

  final List<GPLogRecord> records = <GPLogRecord>[];

  GPLogRecord get last => records.last;

  @override
  void write(GPLogRecord record) => records.add(record);
}
