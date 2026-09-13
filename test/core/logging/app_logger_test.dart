import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/logging/app_logger.dart';
import 'package:ghpockit/core/logging/developer_logger.dart';
import 'package:ghpockit/core/logging/log_redactor.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/recording_logger.dart';

void main() {
  group('GPAppLogger', () {
    test('stamps the record from the injected clock', () {
      final clock = FakeClock(DateTime.utc(2026, 9, 9, 21));
      final logger = RecordingLogger(clock: clock)..info('sync cycle started');

      clock.advance(const Duration(seconds: 30));
      logger.info('sync cycle finished');

      expect(logger.records.map((r) => r.timestamp), <DateTime>[
        DateTime.utc(2026, 9, 9, 21),
        DateTime.utc(2026, 9, 9, 21, 0, 30),
      ]);
    });

    test('every shorthand lands at its own level', () {
      final logger = RecordingLogger(clock: FakeClock())
        ..debug('d')
        ..info('i')
        ..warn('w')
        ..error('e');

      expect(logger.records.map((r) => r.level), GPLogLevel.values);
    });

    test('redacts fields before they reach the sink — golden rule 9', () {
      final logger = RecordingLogger(clock: FakeClock())..warn('mutation push failed', fields: {'id': 'm1', 'amountMinor': 1250000});

      expect(logger.last.fields, {'id': 'm1', 'amountMinor': redactedPlaceholder});
    });

    test('passes error and stack trace through untouched', () {
      final stack = StackTrace.current;
      final failure = Exception('boom');
      final logger = RecordingLogger(clock: FakeClock())..error('uncaught', error: failure, stackTrace: stack);

      expect(logger.last.error, same(failure));
      expect(logger.last.stackTrace, same(stack));
    });

    test('a record with no fields carries an empty map, not null', () {
      final logger = RecordingLogger(clock: FakeClock())..info('app bootstrapped');

      expect(logger.last.fields, isEmpty);
    });
  });

  group('GPLogLevel.isAtLeast', () {
    test('orders debug < info < warn < error', () {
      expect(GPLogLevel.error.isAtLeast(GPLogLevel.debug), isTrue);
      expect(GPLogLevel.info.isAtLeast(GPLogLevel.info), isTrue);
      expect(GPLogLevel.debug.isAtLeast(GPLogLevel.info), isFalse);
    });
  });

  group('GPDeveloperLogger', () {
    /// Collects what would have reached `dart:developer`, which a test process
    /// cannot read back.
    ({List<String> messages, List<({String name, int level})> tags, GPLogSink sink}) capture() {
      final messages = <String>[];
      final tags = <({String name, int level})>[];

      return (
        messages: messages,
        tags: tags,
        sink: (String message, {DateTime? time, String name = '', int level = 0, Object? error, StackTrace? stackTrace}) {
          messages.add(message);
          tags.add((name: name, level: level));
        },
      );
    }

    test('drops records below minLevel', () {
      final captured = capture();

      GPDeveloperLogger(clock: FakeClock(), sink: captured.sink)
        ..debug('dropped')
        ..info('kept');

      expect(captured.messages, <String>['kept']);
    });

    test('minLevel defaults to info, so debug has to be opted into', () {
      final captured = capture();

      GPDeveloperLogger(clock: FakeClock(), minLevel: GPLogLevel.debug, sink: captured.sink).debug('kept');

      expect(captured.messages, <String>['kept']);
    });

    test('never emits a raw sensitive value, not even in the message it builds', () {
      final captured = capture();

      GPDeveloperLogger(clock: FakeClock(), sink: captured.sink).warn('mutation push failed', fields: {'id': 'm1', 'amountMinor': 1250000});

      expect(captured.messages.single, contains('m1'));
      expect(captured.messages.single, contains(redactedPlaceholder));
      expect(captured.messages.single, isNot(contains('1250000')));
    });

    test('tags each record with its level name and DevTools level', () {
      final captured = capture();

      GPDeveloperLogger(clock: FakeClock(), sink: captured.sink)
        ..info('i')
        ..error('e');

      expect(captured.tags, <({String name, int level})>[(name: 'pockit.info', level: 800), (name: 'pockit.error', level: 1000)]);
    });
  });
}
