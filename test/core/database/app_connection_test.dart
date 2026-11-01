import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';

/// Every other database test runs `NativeDatabase.memory()` on the test isolate. This one opens the connection the app opens, through the real
/// background isolate, so dropping `shareAcrossIsolates` cannot pass unnoticed (ADR-0001, W8 T6).
void main() {
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync('pockit-connection'));
  tearDown(() => directory.deleteSync(recursive: true));

  GPAppDatabase open(String name) => GPAppDatabase.forTesting(
    // Both paths given, so `drift_flutter` does not ask `path_provider`, which has no plugin under `flutter test`.
    openAppConnection(name: name, databaseDirectory: () async => directory, tempDirectoryPath: () async => directory.path),
  );

  test('two connections opened by name share one instance: a write through one reaches the other one’s watch', () async {
    final first = open('shared');
    final second = open('shared');
    addTearDown(() async {
      await first.close();
      await second.close();
    });

    final seen = <int>[];
    final watching = Completer<void>();
    final updated = Completer<void>();
    final subscription = first.customSelect('SELECT count(*) AS n FROM settings', readsFrom: {first.settingsTable}).watch().listen((rows) {
      seen.add(rows.single.read<int>('n'));
      if (!watching.isCompleted) watching.complete();
      if (seen.last == 1 && !updated.isCompleted) updated.complete();
    });
    addTearDown(subscription.cancel);

    // The first count must be in before the write, or a late first read would see the row with no update crossing between the connections.
    await watching.future;
    await second.into(second.settingsTable).insert(SettingsTableCompanion.insert(key: 'locale.selected', value: 'vi', updatedAt: 1));

    // Real time on purpose: the update crosses isolates. Two separate connections to the file would never deliver it.
    await updated.future.timeout(const Duration(seconds: 5));
    expect(seen, [0, 1]);
  });

  test('stores one file per name in the directory it is given', () async {
    final database = open('pockit');
    addTearDown(database.close);

    await database.customSelect('SELECT 1').get();

    expect(File('${directory.path}/pockit.sqlite').existsSync(), isTrue);
  });
}
