import 'package:drift/drift.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/features/categories/data/tables/categories_table.dart';

part 'category_dao.g.dart';

/// Row-level access to `categories` (W3 T5), written to the same shape as `AccountDao` — `docs/patterns/local-storage-with-drift.md` §6.2.
///
/// The two rules that shape it are the ones stated in full there and not repeated: **it speaks SQL and holds no policy** (no clock, no UUIDs, no outbox),
/// and it is **deliberately absent from `@DriftDatabase(daos: ...)`** so that DI constructs exactly one of it.
///
/// What is new here is [insertMissing], which exists because this table is the first one the app writes to without a user asking.
@DriftAccessor(tables: [CategoriesTable])
class CategoryDao extends DatabaseAccessor<GPAppDatabase> with _$CategoryDaoMixin {
  CategoryDao(super.attachedDatabase);

  /// The live category list for one owner, optionally narrowed to one [type].
  ///
  /// [ownerId] is required for the same W10 reason as `AccountDao.watchAccounts`, and it is what makes `categories_owner_id_type` usable: a query filtering
  /// only on `type` can scan that index but never seek into it.
  ///
  /// [type] is the raw storage string, not a `CategoryType` — the DAO deals in rows, and the enum is the mapper's business at T6 (§3, three-model rule).
  ///
  /// Ordered by creation then id, not by name, for the reason `AccountDao` spells out: SQLite's `BINARY` collation sorts "Ăn uống" after "Ví", and a list
  /// that claims to be alphabetical and is not is worse than one that is honestly chronological. It matters more here than it did there — a seeded list is
  /// inserted in one batch, so creation order is the order the seeder declared, which is the order a reader of `DefaultCategory` expects.
  Stream<List<CategoryRow>> watchCategories(String ownerId, {String? type}) {
    final query = select(categoriesTable)
      ..where((t) => t.ownerId.equals(ownerId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt), (t) => OrderingTerm.asc(t.id)]);

    if (type != null) {
      query.where((t) => t.type.equals(type));
    }

    return query.watch();
  }

  /// One live row by id, re-emitting until it is gone.
  Stream<CategoryRow?> watchCategory(String ownerId, String id) {
    return (select(categoriesTable)..where((t) => t.id.equals(id) & t.ownerId.equals(ownerId) & t.deletedAt.isNull())).watchSingleOrNull();
  }

  /// One row by id, tombstone included — the reconciliation read `RemoteChangeApplier` needs at W14. Same exception as `AccountDao.findById`.
  Future<CategoryRow?> findById(String id) => (select(categoriesTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertCategory(CategoriesTableCompanion row) => into(categoriesTable).insert(row);

  /// Inserts the rows that are not there yet and leaves the rest alone. Returns how many were actually written.
  ///
  /// **The seeder's entry point, and the reason it is `insertOrIgnore` rather than a read-then-write.** Checking "are there categories already?" and then
  /// inserting is two statements with a gap in the middle: two isolates — the UI and W7's background worker — can both pass the check and both insert. A
  /// single `INSERT OR IGNORE` inside one transaction has no gap, and with the seeder's derived ids the conflict it ignores is the primary key, not a
  /// guess.
  ///
  /// It is not a general-purpose upsert: an existing row is left **exactly** as it is, renames and all. Re-running the seeder must never undo the user's
  /// edits, which an `insertOrReplace` would do silently.
  ///
  /// Returns the count so a caller can tell "seeded 11" from "seeded 0, they were already there" — the distinction W6's "restore defaults" reports.
  Future<int> insertMissing(List<CategoriesTableCompanion> rows) async {
    if (rows.isEmpty) return 0;

    // One transaction, so a crash halfway cannot leave a half-seeded list — golden rule 3's reasoning, applied to a batch that has no outbox half yet.
    return transaction(() async {
      final before = await _countAll();
      await batch((b) => b.insertAll(categoriesTable, rows, mode: InsertMode.insertOrIgnore));

      return await _countAll() - before;
    });
  }

  /// Applies [patch] to a live row, guarded on [baseVersion]. Returns the number of rows written; **0 means the row moved under us** (§7).
  ///
  /// `version` is never written here and `updated_at` is always stamped from [now] — both for the reasons `AccountDao.updateAccount` gives.
  Future<int> updateCategory(String id, {required int baseVersion, required CategoriesTableCompanion patch, required int now}) {
    return (update(categoriesTable)..where((t) => t.id.equals(id) & t.version.equals(baseVersion) & t.deletedAt.isNull())).write(
      patch.copyWith(updatedAt: Value(now)),
    );
  }

  /// Stamps the tombstone (golden rule 5). Returns the number of rows written; 0 means there was no live row with that id.
  ///
  /// **A system category is deletable.** `is_system` is provenance, not a lock: a user who never spends on education should be able to make that row go
  /// away, and refusing would mean a permanent list of things they do not use. Re-seeding will not bring it back either, because [insertMissing] matches on
  /// the primary key and the tombstoned row still holds it — which is the behaviour a soft delete is supposed to have, and would not have if seeded ids
  /// were random.
  Future<int> softDelete(String id, {required int now}) {
    return (update(categoriesTable)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
      CategoriesTableCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<int> _countAll() async {
    final count = categoriesTable.id.count();

    return (selectOnly(categoriesTable)..addColumns([count])).map((row) => row.read(count)!).getSingle();
  }
}
