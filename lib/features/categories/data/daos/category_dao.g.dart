// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_dao.dart';

// ignore_for_file: type=lint
mixin _$CategoryDaoMixin on DatabaseAccessor<GPAppDatabase> {
  $CategoriesTableTable get categoriesTable => attachedDatabase.categoriesTable;
  CategoryDaoManager get managers => CategoryDaoManager(this);
}

class CategoryDaoManager {
  final _$CategoryDaoMixin _db;
  CategoryDaoManager(this._db);
  $$CategoriesTableTableTableManager get categoriesTable => $$CategoriesTableTableTableManager(
    _db.attachedDatabase,
    _db.categoriesTable,
  );
}
