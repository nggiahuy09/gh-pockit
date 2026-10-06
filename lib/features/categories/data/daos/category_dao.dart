import 'package:drift/drift.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/features/categories/data/tables/categories_table.dart';

part 'category_dao.g.dart';

/// Deliberately absent from `@DriftDatabase(daos: ...)`, so DI builds the only instance.
@DriftAccessor(tables: [CategoriesTable])
class CategoryDao extends DatabaseAccessor<GPAppDatabase> with _$CategoryDaoMixin {
  CategoryDao(super.attachedDatabase);

  /// [type] is a `CategoryType.storageValue`. Not ordered by name: SQLite's `BINARY` collation misorders Vietnamese.
  Stream<List<CategoryRow>> watchCategories(String ownerId, {String? type}) {
    final query = select(categoriesTable)
      ..where((t) => t.ownerId.equals(ownerId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt), (t) => OrderingTerm.asc(t.id)]);

    if (type != null) {
      query.where((t) => t.type.equals(type));
    }

    return query.watch();
  }

  Stream<CategoryRow?> watchCategory(String ownerId, String id) {
    return (select(categoriesTable)..where((t) => t.id.equals(id) & t.ownerId.equals(ownerId) & t.deletedAt.isNull())).watchSingleOrNull();
  }

  /// Includes tombstones, unlike the watches, so a caller can tell "deleted" from "never existed".
  Future<CategoryRow?> findById(String id) => (select(categoriesTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertCategory(CategoriesTableCompanion row) => into(categoriesTable).insert(row);

  /// Inserts the rows not there yet, leaves existing ones exactly as they are, and returns how many it wrote.
  /// `INSERT OR IGNORE` rather than a read-then-write two isolates could race, and never `OR REPLACE`, which would undo a user's rename.
  Future<int> insertMissing(List<CategoriesTableCompanion> rows) async {
    if (rows.isEmpty) return 0;

    // One transaction around both counts and the batch, so no other write lands in between.
    return transaction(() async {
      final before = await _countAll();
      await batch((b) => b.insertAll(categoriesTable, rows, mode: InsertMode.insertOrIgnore));

      return await _countAll() - before;
    });
  }

  /// Guarded on [baseVersion]: 0 rows written means a stale version or no live row (§7). Never writes `version`, which is the server's.
  Future<int> updateCategory(String id, {required int baseVersion, required CategoriesTableCompanion patch, required int now}) {
    return (update(categoriesTable)..where((t) => t.id.equals(id) & t.version.equals(baseVersion) & t.deletedAt.isNull())).write(
      patch.copyWith(updatedAt: Value(now)),
    );
  }

  /// 0 means no live row with [id]. System rows too, on purpose: the tombstone keeps the id, so re-seeding does not bring the row back.
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
