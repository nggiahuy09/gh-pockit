import 'package:drift/drift.dart';

/// The outbox (ADR-0044). Internal, so no sync columns, and a row is hard-deleted once the server has answered (golden rules 5, 6).
@DataClassName('SyncMutationRow')
// Ready to push is one range on this index: `status = 'pending' AND next_attempt_at <= :now`.
@TableIndex(name: 'sync_mutations_status_next_attempt_at', columns: {#status, #nextAttemptAt})
// At most one unsent mutation per entity: a later write folds into it (ADR-0044), so a second one is a bug, refused with the write. Partial,
// so a lookup must repeat this WHERE with literals, not bound values, for SQLite to use it.
@TableIndex.sql(
  "CREATE UNIQUE INDEX sync_mutations_unattempted_entity ON sync_mutations (entity_type, entity_id) WHERE status = 'pending' AND attempt_count = 0",
)
// Not final: drift generates a subclass in another library.
class SyncMutationsTable extends Table {
  TextColumn get id => text()();

  /// No vocabulary CHECK on this, [operation] or [status]: the mapper refuses an unknown value on read (ADR-0009).
  TextColumn get entityType => text()();

  /// No foreign key: it points into whichever table [entityType] names.
  TextColumn get entityId => text()();

  TextColumn get operation => text()();

  TextColumn get payloadJson => text()();

  /// Minted once at enqueue and kept across every retry; unique, or the server would treat two mutations as one.
  TextColumn get idempotencyKey => text().unique()();

  IntColumn get createdAt => integer()();

  // Drift's idiom for a column CHECK, which `recursive_getters` reads as recursion; the generated table overrides this getter.
  // ignore: recursive_getters
  IntColumn get attemptCount => integer().check(attemptCount.isBiggerOrEqualValue(0))();

  /// Not null, unlike blueprint §20: enqueue sets it to [createdAt], so "ready" needs no `IS NULL` branch.
  IntColumn get nextAttemptAt => integer()();

  TextColumn get status => text()();

  /// A code only, never a server message: one can echo the payload back (golden rule 9).
  TextColumn get lastErrorCode => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  String get tableName => 'sync_mutations';
}
