import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GoTrue logs the whole session, tokens included, at FINEST through `package:logging`. Those records are dropped only while nothing in the app
/// listens; a listener (a Sentry integration, a debug print of `Logger.root`) would leak them (ADR-0039, golden rule 9).
void main() {
  test('nothing in lib/ listens to package:logging or prints', () {
    final offenders = <String>[];
    final pattern = RegExp(r'Logger\.root|\.onRecord|hierarchicalLoggingEnabled|package:logging/|\bprint\(|\bdebugPrint\(');

    for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;
        if (pattern.hasMatch(line)) offenders.add('${file.path}:${i + 1}: $line');
      }
    }

    expect(offenders, isEmpty, reason: 'A logging listener or print must filter GoTrue and redact first');
  });
}
