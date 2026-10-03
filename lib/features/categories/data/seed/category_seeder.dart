import 'package:drift/drift.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/core/utils/uuid_generator.dart';
import 'package:ghpockit/features/categories/data/daos/category_dao.dart';
import 'package:ghpockit/features/categories/data/seed/default_categories.dart';

/// Writes the default categories for an owner, once (W3 T5).
///
/// **Separate from the DAO because it is policy**, which `CategoryDao` deliberately holds none of: which categories exist, that they are `is_system`, that
/// they open at `version` 1, and where their ids come from. The DAO is handed finished companions, exactly as `AccountMapper` hands it finished companions
/// at T6 — and the repository at T6 will call this rather than reimplementing it.
///
/// **Idempotent, and by construction rather than by checking.** Every run builds the same ids for the same owner, and `insertMissing` ignores the ones
/// already present. So calling it on every launch is safe, calling it from two isolates at once is safe, and a category the user deleted stays deleted —
/// its tombstoned row still holds the id.
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

  /// Seeds anything missing and returns how many rows were written — 0 on every launch after the first.
  Future<int> seedDefaults() {
    final now = _clock.nowEpochMillis();

    return _dao.insertMissing([for (final category in DefaultCategory.values) _companionFor(category, now)]);
  }

  /// The id a seeded row gets: **derived from the owner and the key, not minted**.
  ///
  /// This is the decision the whole seeder turns on. Two installs of one account each run this offline, before they have ever seen each other's data; with
  /// `v7()` they would write two "Food" rows with different ids, and the first sync would hand the user a list with everything in it twice — a duplicate
  /// nobody can automatically merge, because by then both rows may have transactions. Deriving the id makes both devices agree, so the pull at W14 matches
  /// on the primary key and the second copy never exists.
  ///
  /// The owner is part of the name and not just the key, or every user on the server would share one set of category ids.
  ///
  /// It is a documented exception to golden rule 4's "v4/v7" — see [GPUuidGenerator.v5], which explains why the rule's actual intent is untouched.
  String _idFor(DefaultCategory category) => _uuidGenerator.v5('$_ownerId|${category.nameKey}');

  CategoriesTableCompanion _companionFor(DefaultCategory category, int now) => CategoriesTableCompanion.insert(
    id: _idFor(category),
    ownerId: _ownerId,
    // `name` stays absent, not empty. Null is what makes "the user has not renamed this" a fact the row states, so `categoryDisplayName` knows to resolve
    // the key — and an empty string would satisfy the table's CHECK while rendering as a blank line.
    nameKey: Value(category.nameKey),
    type: category.type.storageValue,
    iconKey: Value(category.iconKey),
    isSystem: true,
    createdAt: now,
    updatedAt: now,
    // 1, like any other locally created row. A seeded category is not special to sync: it is pushed, versioned and conflicted exactly like one the user
    // typed, and pretending otherwise (version 0, or a "never sync this" flag) would make the very first pull a special case.
    version: 1,
  );
}
