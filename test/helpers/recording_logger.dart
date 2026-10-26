import 'package:ghpockit/core/logging/app_logger.dart';

final class RecordingLogger extends GPAppLogger {
  RecordingLogger(super.clock);

  final List<GPLogRecord> _records = [];

  List<GPLogRecord> get records => List.unmodifiable(_records);

  GPLogRecord get last => _records.last;

  @override
  void write(GPLogRecord record) => _records.add(record);
}
