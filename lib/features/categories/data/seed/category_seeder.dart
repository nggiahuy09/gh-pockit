import 'package:drift/drift.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/core/utils/uuid_generator.dart';
import 'package:ghpockit/features/categories/data/daos/category_dao.dart';
import 'package:ghpockit/features/categories/data/seed/default_categories.dart';

/// Safe on every launch and from two isolates at once: the ids are derived, and [CategoryDao.insertMissing] skips rows already there, deleted ones included.
class CategorySeeder {
  const CategorySeeder({required CategoryDao dao, required GPClock clock, required GPUuidGenerator uuidGenerator, required String ownerId})
    : _dao = dao,
      _clock = clock,
      _uuidGenerator = uuidGenerator,
      _ownerId = ownerId;

  final CategoryDao _dao;
  final GPClock _clock;
  final GPUuidGenerator _uuidGenerator;
  final String _ownerId;

  /// Returns how many rows were written: 0 on every launch after the first.
  Future<int> seedDefaults() {
    final now = _clock.nowEpochMillis();

    return _dao.insertMissing([for (final category in DefaultCategory.values) _companionFor(category, now)]);
  }

  /// v5, not v7: two offline devices must mint the same id for "Food", so sync reconciles it rather than duplicating it (ADR-0002 amendment).
  /// The owner is part of the input, or every user would share one set of ids.
  String _idFor(DefaultCategory category) => _uuidGenerator.v5('$_ownerId|${category.nameKey}');

  CategoriesTableCompanion _companionFor(DefaultCategory category, int now) => CategoriesTableCompanion.insert(
    id: _idFor(category),
    ownerId: _ownerId,
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
