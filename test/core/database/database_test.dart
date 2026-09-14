import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';

/// The first query this app ever runs (W2 T2).
///
/// What is under test is not the `settings` table — it is that ADR-0001 actually holds: that a schema declared in Dart reaches SQLite, that a write is
/// visible to a read, and above all that a `watch()` re-emits on its own. That last one is the property the whole decision rests on: golden rule 1 says the
/// UI reads the local DB and nothing else, and it is only livable because a write from anywhere — a tap, or a sync pull in P4 — repaints the list with no
/// manual invalidation. If that ever stops being true, it should fail here rather than as a stale screen.
void main() {
  late GPAppDatabase db;

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  SettingsTableCompanion setting(String key, String value, {int at = 1757800000000}) => SettingsTableCompanion.insert(key: key, value: value, updatedAt: at);

  test('creates the schema at v1 and round-trips a row', () async {
    expect(db.schemaVersion, 1);

    await db.into(db.settingsTable).insert(setting('locale.selected', 'vi'));

    final row = await (db.select(db.settingsTable)..where((t) => t.key.equals('locale.selected'))).getSingle();

    expect(row.value, 'vi');
    // Epoch millis, not an ISO string (§6). Asserted because an `IntColumn` holding a formatted date would still pass every other test in this file.
    expect(row.updatedAt, 1757800000000);
  });

  test('a watched query re-emits when the row it selects is written', () async {
    final query = db.select(db.settingsTable)..where((t) => t.key.equals('locale.selected'));

    final emissions = <String?>[];
    final subscription = query.watchSingleOrNull().listen((row) => emissions.add(row?.value));

    // No `Future.delayed`: `pump` here only yields to the event loop so the stream can deliver what is already queued. Sync tests will need a fake clock
    // (§8); a stream that has already fired needs nothing but a turn of the loop.
    await pumpEventQueue();
    await db.into(db.settingsTable).insert(setting('locale.selected', 'vi'));
    await pumpEventQueue();

    await db.into(db.settingsTable).insertOnConflictUpdate(setting('locale.selected', 'en', at: 1757800005000));
    await pumpEventQueue();

    await subscription.cancel();

    // null (no row yet) → 'vi' → 'en'. Nothing invalidated the query by hand; the writes did it.
    expect(emissions, [null, 'vi', 'en']);
  });

  test('a watcher re-emits on any write to its table, not just to the row it selects', () async {
    await db.into(db.settingsTable).insert(setting('locale.selected', 'vi'));

    final emissions = <String?>[];
    final subscription = (db.select(db.settingsTable)..where((t) => t.key.equals('locale.selected'))).watchSingleOrNull().listen((row) => emissions.add(row?.value));

    await pumpEventQueue();
    await db.into(db.settingsTable).insert(setting('theme.mode', 'dark'));
    await pumpEventQueue();

    await subscription.cancel();

    // 'vi' twice — the second emission is the unrelated `theme.mode` insert. Drift invalidates a stream query per *table*, not per row, so a watcher
    // re-runs its query whenever anything in `settings` changes, even when the result is identical.
    //
    // Harmless here (one table, a handful of rows) and exactly the thing to remember at W8: a `watchTransactions(query)` over 50k rows re-runs on every
    // insert from a sync pull, whether or not a single visible row moved. The fix when it bites is `.distinct()` on the stream, or a narrower query —
    // not a hand-rolled invalidation scheme, which is the `sqflite` failure mode ADR-0001 rejected. Written down as a test so the behaviour is a known
    // property rather than a surprise in a benchmark.
    expect(emissions, ['vi', 'vi']);
  });

  test('beforeOpen turns on foreign key enforcement', () async {
    // Off by default in SQLite and re-set per connection, so this asserts the `beforeOpen` hook ran on the connection the test is actually using — not
    // that the pragma exists. Without it, every foreign key added from W4 onwards would be documentation.
    final result = await db.customSelect('PRAGMA foreign_keys').getSingle();

    expect(result.data.values.first, 1);
  });
}
