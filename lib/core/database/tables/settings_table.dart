import 'package:drift/drift.dart';

/// Device-local and never synced, hence no sync columns (§6). Key/value rather than typed columns (ADR-0001, open question 3).
@DataClassName('SettingRow')
// Not final: drift generates a subclass in another library.
class SettingsTable extends Table {
  /// Dotted namespace, e.g. `locale.selected`.
  TextColumn get key => text()();

  TextColumn get value => text()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};

  @override
  String get tableName => 'settings';
}
