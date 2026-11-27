import 'package:drift/drift.dart';

/// The sync engine's own state (cursor, device id, last sync). Not in `settings`, which outlives a sign-out: another account's cursor
/// would skip that account's older rows (ADR-0044). Internal, so no sync columns.
@DataClassName('SyncMetadataRow')
// Not final: drift generates a subclass in another library.
class SyncMetadataTable extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};

  @override
  String get tableName => 'sync_metadata';
}
