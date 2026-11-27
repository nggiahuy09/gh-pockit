import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/database/owner_context.dart';
import '../../../../core/database/owner_id.dart';
import '../../../../core/sync/sync_entity_type.dart';
import '../../../../core/sync/sync_operation.dart';
import '../../../../core/sync/sync_queue_repository.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/uuid_generator.dart';
import '../daos/category_dao.dart';
import '../mapper/category_mapper.dart';
import 'default_categories.dart';

/// Safe on every launch and from two isolates at once: the ids are derived, and [CategoryDao.insertMissing] skips rows already there.
final class CategorySeeder {
  const CategorySeeder({
    required GPClock clock,
    required CategoryDao dao,
    required GPOwnerContext ownerContext,
    required GPUuidGenerator uuidGenerator,
    required GPSyncQueueRepository syncQueue,
  }) : _clock = clock,
       _dao = dao,
       _ownerContext = ownerContext,
       _uuidGenerator = uuidGenerator,
       _syncQueue = syncQueue;

  final GPClock _clock;
  final CategoryDao _dao;
  final GPOwnerContext _ownerContext;
  final GPUuidGenerator _uuidGenerator;
  final GPSyncQueueRepository _syncQueue;

  /// v5 over owner + key: the same id on every device (ADR-0002 amendment); a claim re-derives it (ADR-0040).
  static String seededId(GPUuidGenerator uuidGenerator, {required String nameKey, required String ownerId}) => uuidGenerator.v5('$ownerId|$nameKey');

  /// For the current owner; returns how many rows were written.
  Future<int> seedDefaults() {
    final now = _clock.nowEpochMillis();
    final ownerId = _ownerContext.current;

    return _dao.transaction(() async {
      final inserted = await _dao.insertMissing([for (final category in DefaultCategory.values) _companionFor(category, now, ownerId)]);
      // Pushed like any row: a transaction in it needs it on the server (ADR-0044). A `'local'` seed waits for the claim, which queues it.
      if (ownerId != localOwnerId) {
        for (final id in inserted) {
          final row = await _dao.findById(id);
          if (row == null) continue;
          await _syncQueue.enqueue(entityType: GPSyncEntityType.category, entityId: id, operation: GPSyncOperation.create, payload: row.toSyncPayload());
        }
      }
      return inserted.length;
    });
  }

  CategoriesTableCompanion _companionFor(DefaultCategory category, int now, String ownerId) => CategoriesTableCompanion.insert(
    id: seededId(_uuidGenerator, nameKey: category.nameKey, ownerId: ownerId),
    ownerId: ownerId,
    // No `name`: null means "not renamed", so the key is what gets translated.
    nameKey: Value(category.nameKey),
    type: category.type.storageValue,
    iconKey: Value(category.iconKey),
    isSystem: true,
    createdAt: now,
    updatedAt: now,
    version: 1,
  );
}
