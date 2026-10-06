import 'package:drift/drift.dart';

/// Device-local and never synced, hence no sync columns (§6). Key/value rather than typed columns (ADR-0001, open question 3).
@DataClassName('SettingRow')
class SettingsTable extends Table {
  /// Dotted namespace, e.g. `locale.selected`.
  TextColumn get key => text()();

  TextColumn get value => text()();

  /// Epoch millis, UTC.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};

  /// Explicit, so renaming the Dart class is not a schema change.
  @override
  String get tableName => 'settings';
}
