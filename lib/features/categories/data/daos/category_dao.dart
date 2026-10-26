import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../tables/categories_table.dart';

part 'category_dao.g.dart';

/// Not listed in `@DriftDatabase(daos:)`, so DI builds the only instance.
@DriftAccessor(tables: [CategoriesTable])
base class CategoryDao extends DatabaseAccessor<GPAppDatabase> with _$CategoryDaoMixin {
  CategoryDao(super.attachedDatabase);

  /// [type] is a `CategoryType.storageValue`. Not ordered by name: SQLite's `BINARY` collation misorders Vietnamese.
  Stream<List<CategoryRow>> watchCategories({required String ownerId, String? type}) {
    final query = select(categoriesTable)
      ..where((t) => t.ownerId.equals(ownerId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt), (t) => OrderingTerm.asc(t.id)]);

    if (type != null) query.where((t) => t.type.equals(type));

    return query.watch();
  }

  Stream<CategoryRow?> watchCategory({required String id, required String ownerId}) {
    return (select(categoriesTable)..where((t) => t.id.equals(id) & t.ownerId.equals(ownerId) & t.deletedAt.isNull())).watchSingleOrNull();
  }

  /// Includes tombstones, unlike the watches, so a caller can tell "deleted" from "never existed".
  Future<CategoryRow?> findById(String id) => (select(categoriesTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertCategory(CategoriesTableCompanion row) => into(categoriesTable).insert(row);

  /// Returns how many rows it wrote. `INSERT OR IGNORE`, never `OR REPLACE`, which would undo a user's rename.
  Future<int> insertMissing(List<CategoriesTableCompanion> rows) async {
    if (rows.isEmpty) return 0;

    // One transaction around both counts and the batch, so no other write lands in between.
    return transaction(() async {
      final before = await _countAll();
      await batch((b) => b.insertAll(categoriesTable, rows, mode: InsertMode.insertOrIgnore));

      return await _countAll() - before;
    });
  }

  /// Never writes `version`, which is the server's.
  Future<int> updateCategory(String id, {required CategoriesTableCompanion patch, required int baseVersion, required int now}) {
    return (update(categoriesTable)..where((t) => t.id.equals(id) & t.version.equals(baseVersion) & t.deletedAt.isNull())).write(patch.copyWith(updatedAt: Value(now)));
  }

  /// System rows too: the tombstone keeps the id, so re-seeding does not bring the row back.
  Future<int> softDelete(String id, {required int now}) {
    return (update(categoriesTable)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(CategoriesTableCompanion(updatedAt: Value(now), deletedAt: Value(now)));
  }

  Future<int> _countAll() async {
    final count = categoriesTable.id.count();

    return (selectOnly(categoriesTable)..addColumns([count])).map((row) => row.read(count)!).getSingle();
  }
}
