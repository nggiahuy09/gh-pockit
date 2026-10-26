import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../tables/accounts_table.dart';

part 'account_dao.g.dart';

/// Not listed in `@DriftDatabase(daos:)`: that would generate a second instance beside the one DI hands out.
@DriftAccessor(tables: [AccountsTable])
base class AccountDao extends DatabaseAccessor<GPAppDatabase> with _$AccountDaoMixin {
  AccountDao(super.attachedDatabase);

  /// By creation, not name: SQLite's `BINARY` collation misorders Vietnamese.
  Stream<List<AccountRow>> watchAccounts(String ownerId, {bool includeArchived = false}) {
    final query = select(accountsTable)
      ..where((t) => t.ownerId.equals(ownerId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt), (t) => OrderingTerm.asc(t.id)]);

    // Drift ANDs successive `where` clauses.
    if (!includeArchived) query.where((t) => t.isArchived.equals(false));

    return query.watch();
  }

  Stream<AccountRow?> watchAccount({required String id, required String ownerId}) {
    return (select(accountsTable)..where((t) => t.id.equals(id) & t.ownerId.equals(ownerId) & t.deletedAt.isNull() & t.isArchived.equals(false))).watchSingleOrNull();
  }

  /// The one read that includes tombstones, so a caller can tell a deleted row from one that never existed.
  Future<AccountRow?> findById(String id) => (select(accountsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertAccount(AccountsTableCompanion row) => into(accountsTable).insert(row);

  /// Never bumps `version`: the server does. Skips tombstones, whose `updated_at` moving would resurrect them at the next sync.
  Future<int> updateAccount(String id, {required AccountsTableCompanion patch, required int baseVersion, required int now}) {
    return (update(accountsTable)..where((t) => t.id.equals(id) & t.version.equals(baseVersion) & t.deletedAt.isNull())).write(patch.copyWith(updatedAt: Value(now)));
  }

  Future<int> archive(String id, {required int now}) => _setArchived(id, now: now, isArchived: true);

  Future<int> unarchive(String id, {required int now}) => _setArchived(id, now: now, isArchived: false);

  /// Moves `updated_at` too, or the delta pull never sees the delete.
  Future<int> softDelete(String id, {required int now}) {
    return (update(accountsTable)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(AccountsTableCompanion(updatedAt: Value(now), deletedAt: Value(now)));
  }

  Future<int> _setArchived(String id, {required int now, required bool isArchived}) {
    return (update(accountsTable)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(AccountsTableCompanion(isArchived: Value(isArchived), updatedAt: Value(now)));
  }
}
