import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';

late GPAppDatabase _db;

void main() {
  setUp(() {
    _db = GPAppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await _db.close();
  });

  test('creates the current schema and round-trips a row', () async {
    // Not pinned to a number: which version `forTesting` lands on belongs to `migration_test.dart`, checked against the fixtures.
    expect(_db.schemaVersion, greaterThanOrEqualTo(1));

    await _db.into(_db.settingsTable).insert(_setting('locale.selected', 'vi'));

    final row = await (_db.select(_db.settingsTable)..where((t) => t.key.equals('locale.selected'))).getSingle();

    expect(row.value, 'vi');
    // Epoch millis, not an ISO string (§6).
    expect(row.updatedAt, 1757800000000);
  });

  test('a watched query re-emits when the row it selects is written', () async {
    final query = _db.select(_db.settingsTable)..where((t) => t.key.equals('locale.selected'));

    final emissions = <String?>[];
    final subscription = query.watchSingleOrNull().listen((row) => emissions.add(row?.value));

    // A turn of the event loop, never `Future.delayed`: the stream only has to deliver what is already queued.
    await pumpEventQueue();
    await _db.into(_db.settingsTable).insert(_setting('locale.selected', 'vi'));
    await pumpEventQueue();

    await _db.into(_db.settingsTable).insertOnConflictUpdate(_setting('locale.selected', 'en', at: 1757800005000));
    await pumpEventQueue();

    await subscription.cancel();

    expect(emissions, [null, 'vi', 'en']);
  });

  test('a watcher re-emits on any write to its table, not just to the row it selects', () async {
    await _db.into(_db.settingsTable).insert(_setting('locale.selected', 'vi'));

    final emissions = <String?>[];
    final subscription = (_db.select(_db.settingsTable)..where((t) => t.key.equals('locale.selected'))).watchSingleOrNull().listen((row) => emissions.add(row?.value));

    await pumpEventQueue();
    await _db.into(_db.settingsTable).insert(_setting('theme.mode', 'dark'));
    await pumpEventQueue();

    await subscription.cancel();

    // Drift invalidates a stream query per table, not per row: the unrelated `theme.mode` insert re-emits an identical 'vi'.
    expect(emissions, ['vi', 'vi']);
  });

  test('beforeOpen turns on foreign key enforcement', () async {
    // Off by default in SQLite and set per connection, so this shows the hook ran on the connection in use.
    final result = await _db.customSelect('PRAGMA foreign_keys').getSingle();

    expect(result.data.values.first, 1);
  });
}

SettingsTableCompanion _setting(String key, String value, {int at = 1757800000000}) => SettingsTableCompanion.insert(key: key, value: value, updatedAt: at);
