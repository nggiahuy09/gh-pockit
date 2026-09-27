import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';

/// What the app can do with categories (W3 T6).
///
/// The shape is `AccountRepository`'s and the reasoning is not repeated: reads are streams because golden rule 1 makes the local DB the source of truth,
/// writes are `GPResult` futures because ADR-0006 makes an outcome a value, and `ownerId` appears nowhere because the repository is the layer that knows it.
///
/// Three things are specific to categories:
///
/// - **No archive.** An account is archived to get it out of a picker while it keeps its history; a category has no balance of its own, so the only two
///   states worth having are "in the list" and "deleted". The table has no `is_archived` column and this interface has no method for one.
/// - **Seeding is not here.** `CategorySeeder` runs from `bootstrap()` and nothing on a screen ever asks for it, so putting it on the interface every BLoC
///   depends on would widen the surface for no caller. W6's "restore defaults" button is the first thing that would change that, and it can call the seeder
///   through DI exactly as `bootstrap` does.
/// - **[createCategory] takes no `nameKey`.** A key is ours, not the user's: it identifies a row we seeded. A category created on this interface is by
///   definition user-made, so it carries a typed name, `is_system = false`, and no key — and there is no parameter through which a caller could pretend
///   otherwise.
///
/// The failure vocabulary is the same four as accounts: [GPValidationFailure] from [createCategory] (the only method taking raw input),
/// [GPConflictFailure] from [updateCategory] (the only guarded write), [GPNotFoundFailure] from anything taking an id, and [GPDatabaseFailure] from
/// anywhere. No network failure — nothing here talks to a server (§12.5).
abstract class CategoryRepository {
  const CategoryRepository();

  /// The live category list, re-emitting on every change to the table, optionally narrowed to one [type].
  ///
  /// [type] is on the read rather than left to the caller's `.where` because it is what the composite index is for: filtering in Dart would pull every row
  /// out of SQLite to throw half away, and the picker at W6 asks for exactly one type at a time.
  ///
  /// Ordered by creation, not alphabetically — SQLite's `BINARY` collation would sort "Ăn uống" after "Ví". Sorting for display happens in Dart, where the
  /// locale is known, and for this list that matters more than for accounts: a seeded list's stored names are *keys*, so alphabetical order over the column
  /// would not even be alphabetical over what the user reads.
  ///
  /// Errors arrive on the stream's error channel and are always a [GPFailure], same as `AccountRepository.watchAccounts`.
  Stream<List<CategoryEntity>> watchCategories({CategoryType? type});

  /// One category, live. Emits null once it is deleted.
  Stream<CategoryEntity?> watchCategory(String id);

  /// Creates a user-made category and returns it as persisted.
  ///
  /// Takes fields rather than an entity because the id comes from `GPUuidGenerator` and the timestamps from `GPClock`, both of which live behind this
  /// interface — and a `v7` id here, not the derived `v5` the seeder uses: nothing about a category the user invented is reproducible on another device, so
  /// there is nothing to derive it from.
  Future<GPResult<CategoryEntity>> createCategory({required String name, required CategoryType type, String? iconKey, String? colorKey});

  /// Applies [category] to storage, guarded on its [CategoryEntity.version], and returns the stored result with a fresh `updatedAt`.
  ///
  /// Renaming a seeded category goes through here, and the key survives because [CategoryEntity.update] has no parameter for it.
  Future<GPResult<CategoryEntity>> updateCategory(CategoryEntity category);

  /// Soft-deletes: stamps `deleted_at` (golden rule 5).
  ///
  /// **A system category may be deleted**, because `is_system` is provenance and not a lock — a user who never spends on education should be able to make
  /// that row go away. The seeder will not bring it back: its derived id still belongs to the tombstoned row, so the next `INSERT OR IGNORE` is ignored.
  ///
  /// What happens to transactions already filed under it is W4's decision — cascade, block, or orphan — and this method does not pretend to have made it.
  Future<GPResult<void>> deleteCategory(String id);
}
