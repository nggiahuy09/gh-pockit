// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_dao.dart';

// ignore_for_file: type=lint
mixin _$TransactionDaoMixin on DatabaseAccessor<GPAppDatabase> {
  $AccountsTableTable get accountsTable => attachedDatabase.accountsTable;
  $CategoriesTableTable get categoriesTable => attachedDatabase.categoriesTable;
  $TransactionsTableTable get transactionsTable => attachedDatabase.transactionsTable;
  TransactionDaoManager get managers => TransactionDaoManager(this);
}

class TransactionDaoManager {
  final _$TransactionDaoMixin _db;
  TransactionDaoManager(this._db);
  $$AccountsTableTableTableManager get accountsTable => $$AccountsTableTableTableManager(_db.attachedDatabase, _db.accountsTable);
  $$CategoriesTableTableTableManager get categoriesTable => $$CategoriesTableTableTableManager(
    _db.attachedDatabase,
    _db.categoriesTable,
  );
  $$TransactionsTableTableTableManager get transactionsTable => $$TransactionsTableTableTableManager(
    _db.attachedDatabase,
    _db.transactionsTable,
  );
}
