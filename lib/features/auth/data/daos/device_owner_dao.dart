import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/database/owner_id.dart';
import '../../../../core/database/settings_owner_context.dart';
import '../../../../core/utils/uuid_generator.dart';
import '../../../categories/data/seed/category_seeder.dart';

/// The claim, in one transaction (ADR-0040). Raw SQL: `version = version + 1` has no typed form.
final class DeviceOwnerDao {
  const DeviceOwnerDao(this._db);

  final GPAppDatabase _db;

  Future<int> claimLocalRows({required String userId, required int nowMillis, required GPUuidGenerator uuidGenerator}) => _db.transaction(() async {
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
    return moved;
  });

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
}
