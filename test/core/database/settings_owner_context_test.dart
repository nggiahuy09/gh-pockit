import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/database/settings_owner_context.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/recording_logger.dart';

void main() {
  late GPAppDatabase db;
  late RecordingLogger logger;
  late GPSettingsOwnerContext context;

  setUp(() {
    db = GPAppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    logger = RecordingLogger(FakeClock());
    context = GPSettingsOwnerContext(database: db, logger: logger);
  });

  tearDown(() async {
    await context.dispose();
    await db.close();
  });

  test('a device nobody claimed is local', () async {
    await context.load();

    expect(context.current, localOwnerId);
  });

  test('loads the owner a claim wrote', () async {
    await db.into(db.settingsTable).insert(SettingsTableCompanion.insert(key: GPSettingsOwnerContext.storageKey, value: 'uid-1', updatedAt: 0));

    await context.load();

    expect(context.current, 'uid-1');
  });

  test('a watch starts with the owner as it is, then follows each change once', () async {
    final seen = <String>[];
    final subscription = context.watch().listen(seen.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    context
      ..adopt('uid-1')
      ..adopt('uid-1');
    await pumpEventQueue();

    expect(seen, [localOwnerId, 'uid-1']);
  });

  test('a database that cannot be read keeps the owner it had, and logs', () async {
    context.adopt('uid-1');
    await db.customStatement('DROP TABLE settings');

    await context.load();

    expect(context.current, 'uid-1');
    expect(logger.last.message, 'owner read failed');
  });
}
