// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_dao.dart';

// ignore_for_file: type=lint
mixin _$AccountDaoMixin on DatabaseAccessor<GPAppDatabase> {
  $AccountsTableTable get accountsTable => attachedDatabase.accountsTable;
  AccountDaoManager get managers => AccountDaoManager(this);
}

class AccountDaoManager {
  final _$AccountDaoMixin _db;
  AccountDaoManager(this._db);
  $$AccountsTableTableTableManager get accountsTable => $$AccountsTableTableTableManager(_db.attachedDatabase, _db.accountsTable);
}
