import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';

void main() {
  late GPAppDatabase db;

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('holds one value per key, the last write winning', () async {
    await db.into(db.syncMetadataTable).insertOnConflictUpdate(SyncMetadataTableCompanion.insert(key: 'pull.cursor', value: 'a'));
    await db.into(db.syncMetadataTable).insertOnConflictUpdate(SyncMetadataTableCompanion.insert(key: 'pull.cursor', value: 'b'));

    final rows = await db.select(db.syncMetadataTable).get();

    expect(rows.map((row) => (row.key, row.value)), [('pull.cursor', 'b')]);
  });
}
