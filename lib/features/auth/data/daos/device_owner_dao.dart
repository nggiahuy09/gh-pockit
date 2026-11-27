import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/database/owner_id.dart';
import '../../../../core/database/settings_owner_context.dart';
import '../../../../core/sync/sync_entity_type.dart';
import '../../../../core/sync/sync_operation.dart';
import '../../../../core/sync/sync_queue_repository.dart';
import '../../../../core/utils/uuid_generator.dart';
import '../../../accounts/data/mapper/account_mapper.dart';
import '../../../categories/data/mapper/category_mapper.dart';
import '../../../categories/data/seed/category_seeder.dart';
import '../../../categories/data/seed/default_categories.dart';
import '../../../transactions/data/daos/transaction_dao.dart';
import '../../../transactions/data/mapper/transaction_mapper.dart';

/// The claim, in one transaction (ADR-0040). Raw SQL: `version = version + 1` has no typed form.
final class DeviceOwnerDao {
  const DeviceOwnerDao(this._db);

  final GPAppDatabase _db;

  /// In `sync_metadata`: the owner's rows from before the outbox are queued, by the claim or by [backfillOutbox].
  static const outboxFilledKey = 'outbox.filled';

  Future<int> claimLocalRows({required String userId, required int nowMillis, required GPUuidGenerator uuidGenerator, required GPSyncQueueRepository syncQueue}) =>
      _db.transaction(() async {
        // Seeded categories change id below; unlike `foreign_keys`, this works inside a transaction.
        await _db.customStatement('PRAGMA defer_foreign_keys = ON');

        final seeded = await (_db.select(_db.categoriesTable)..where((t) => t.ownerId.equals(localOwnerId) & t.nameKey.isNotNull())).get();
        for (final row in seeded) {
          await _reIdSeededCategory(row, CategorySeeder.seededId(uuidGenerator, nameKey: row.nameKey!, ownerId: userId));
        }

        var moved = 0;
        for (final table in const ['accounts', 'categories', 'transactions']) {
          moved += await _db.customUpdate(
            'UPDATE $table SET owner_id = ?, updated_at = ?, version = version + 1 WHERE owner_id = ?',
            variables: [Variable.withString(userId), Variable.withInt(nowMillis), Variable.withString(localOwnerId)],
            updates: {_db.accountsTable, _db.categoriesTable, _db.transactionsTable},
            updateKind: UpdateKind.update,
          );
        }

        await _db.into(_db.settingsTable).insertOnConflictUpdate(SettingsTableCompanion.insert(key: GPSettingsOwnerContext.storageKey, value: userId, updatedAt: nowMillis));
        // A `'local'` row queued nothing (ADR-0044): every row the account now holds goes out as a create, in this same transaction.
        await _enqueueOwnerRows(userId, syncQueue);
        await _markOutboxFilled();
        return moved;
      });

  /// Once per database, for a device that a build without the outbox claimed: queues its rows as the claim now does. Returns how many.
  Future<int> backfillOutbox({required String ownerId, required GPSyncQueueRepository syncQueue}) => _db.transaction(() async {
    // An unclaimed device queues nothing; its claim fills the outbox.
    if (ownerId == localOwnerId) return 0;
    final filled = await (_db.select(_db.syncMetadataTable)..where((t) => t.key.equals(outboxFilledKey))).getSingleOrNull();
    if (filled != null) return 0;

    final queued = await _enqueueOwnerRows(ownerId, syncQueue);
    await _markOutboxFilled();
    return queued;
  });

  /// Parents first, each in creation order, so the push meets the server's foreign keys in order. Tombstones too: the delete has to reach
  /// the server. A transaction the server already has is `synced` and stays out.
  Future<int> _enqueueOwnerRows(String ownerId, GPSyncQueueRepository syncQueue) async {
    Future<void> enqueue(GPSyncEntityType type, String id, Map<String, Object?> payload) =>
        syncQueue.enqueue(entityType: type, entityId: id, operation: GPSyncOperation.create, payload: payload);

    final accounts =
        await (_db.select(_db.accountsTable)
              ..where((t) => t.ownerId.equals(ownerId))
              ..orderBy([(t) => OrderingTerm(expression: t.createdAt), (t) => OrderingTerm(expression: t.id)]))
            .get();
    for (final row in accounts) {
      await enqueue(GPSyncEntityType.account, row.id, row.toSyncPayload());
    }

    final categories =
        await (_db.select(_db.categoriesTable)
              ..where((t) => t.ownerId.equals(ownerId))
              ..orderBy([(t) => OrderingTerm(expression: t.createdAt), (t) => OrderingTerm(expression: t.id)]))
            .get();
    for (final row in categories) {
      await enqueue(GPSyncEntityType.category, row.id, row.toSyncPayload());
    }

    final transactions =
        await (_db.select(_db.transactionsTable)
              ..where((t) => t.ownerId.equals(ownerId) & t.syncStatus.equals(TransactionDao.pendingSyncStatus))
              ..orderBy([(t) => OrderingTerm(expression: t.createdAt), (t) => OrderingTerm(expression: t.id)]))
            .get();
    for (final row in transactions) {
      await enqueue(GPSyncEntityType.transaction, row.id, row.toSyncPayload());
    }

    return accounts.length + categories.length + transactions.length;
  }

  Future<void> _markOutboxFilled() => _db.into(_db.syncMetadataTable).insertOnConflictUpdate(SyncMetadataTableCompanion.insert(key: outboxFilledKey, value: '1'));

  /// Matches the user's own seed on any device (ADR-0002 amendment).
  Future<void> _reIdSeededCategory(CategoryRow row, String newId) async {
    final taken = await (_db.select(_db.categoriesTable)..where((t) => t.id.equals(newId))).getSingleOrNull() != null;

    await _db.customUpdate(
      'UPDATE transactions SET category_id = ? WHERE category_id = ?',
      variables: [Variable.withString(newId), Variable.withString(row.id)],
      updates: {_db.transactionsTable},
      updateKind: UpdateKind.update,
    );

    if (taken) {
      // A duplicate of the user's own seed; never synced, so no tombstone.
      await _db.customUpdate(
        'DELETE FROM categories WHERE id = ?',
        variables: [Variable.withString(row.id)],
        updates: {_db.categoriesTable},
        updateKind: UpdateKind.delete,
      );
    } else {
      await _db.customUpdate(
        'UPDATE categories SET id = ? WHERE id = ?',
        variables: [Variable.withString(newId), Variable.withString(row.id)],
        updates: {_db.categoriesTable},
        updateKind: UpdateKind.update,
      );
    }
  }

  /// Entities with a mutation still in the outbox, whatever its state (ADR-0044). A seed still exactly as seeded does not count: every device
  /// seeds the same one, so a sign-out loses nothing by dropping it (ADR-0042).
  Future<int> countUnsynced() async {
    final seeds = [for (final category in DefaultCategory.values) '${category.nameKey}|${category.iconKey}'];
    final row = await _db
        .customSelect(
          'SELECT count(*) AS unsynced FROM (SELECT DISTINCT m.entity_type, m.entity_id FROM sync_mutations m '
          "LEFT JOIN categories c ON m.entity_type = 'category' AND c.id = m.entity_id "
          "WHERE NOT (m.entity_type = 'category' AND c.name_key IS NOT NULL AND c.name IS NULL AND c.color_key IS NULL AND c.deleted_at IS NULL "
          "AND c.name_key || '|' || COALESCE(c.icon_key, '') IN (${List.filled(seeds.length, '?').join(', ')})))",
          variables: [for (final seed in seeds) Variable.withString(seed)],
          readsFrom: {_db.syncMutationsTable, _db.categoriesTable},
        )
        .getSingle();
    return row.read<int>('unsynced');
  }

  /// Hard delete, children first for the foreign keys: the device's copy goes, the server's stays (ADR-0042). `settings` keeps everything but
  /// the owner. The outbox goes too: it is this owner's, and a sign-out only runs once it holds nothing but untouched seeds.
  Future<int> wipeOwnerRows(String ownerId) => _db.transaction(() async {
    await _db.delete(_db.syncMutationsTable).go();
    var deleted = 0;
    for (final table in const ['transactions', 'categories', 'accounts']) {
      deleted += await _db.customUpdate(
        'DELETE FROM $table WHERE owner_id = ?',
        variables: [Variable.withString(ownerId)],
        updates: {_db.accountsTable, _db.categoriesTable, _db.transactionsTable},
        updateKind: UpdateKind.delete,
      );
    }
    await (_db.delete(_db.settingsTable)..where((t) => t.key.equals(GPSettingsOwnerContext.storageKey))).go();
    return deleted;
  });
}
