import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/uuid_generator.dart';
import '../daos/category_dao.dart';
import 'default_categories.dart';

/// Safe on every launch and from two isolates at once: the ids are derived, and [CategoryDao.insertMissing] skips rows already there.
final class CategorySeeder {
  const CategorySeeder({required GPClock clock, required CategoryDao dao, required GPUuidGenerator uuidGenerator, required String ownerId})
    : _clock = clock,
      _dao = dao,
      _uuidGenerator = uuidGenerator,
      _ownerId = ownerId;

  final GPClock _clock;
  final CategoryDao _dao;
  final GPUuidGenerator _uuidGenerator;
  final String _ownerId;

  /// Returns how many rows were written: 0 on every launch after the first.
  Future<int> seedDefaults() {
    final now = _clock.nowEpochMillis();

    return _dao.insertMissing([for (final category in DefaultCategory.values) _companionFor(category, now)]);
  }

  /// v5, not v7: two offline devices must mint the same id for "Food" (ADR-0002 amendment). The owner is in the input, or every user would share ids.
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
