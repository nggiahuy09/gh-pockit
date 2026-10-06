import 'package:drift/drift.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/features/accounts/data/tables/accounts_table.dart';

part 'account_dao.g.dart';

/// Not listed in `@DriftDatabase(daos:)`: that would generate a second instance beside the one DI hands out.
@DriftAccessor(tables: [AccountsTable])
class AccountDao extends DatabaseAccessor<GPAppDatabase> with _$AccountDaoMixin {
  // `super.attachedDatabase`, not `super.db`: `matching_super_parameters` wants the name drift generated.
  AccountDao(super.attachedDatabase);

  /// Ordered by creation, not name: SQLite's `BINARY` collation would put "Ăn uống" after "Ví", and neither Dart nor `intl` sorts Vietnamese. The screen
  /// shows this order too (ROADMAP Q14).
  Stream<List<AccountRow>> watchAccounts(String ownerId, {bool includeArchived = false}) {
    final query = select(accountsTable)
      ..where((t) => t.ownerId.equals(ownerId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt), (t) => OrderingTerm.asc(t.id)]);

    if (!includeArchived) {
      // Composed, not replaced: drift ANDs successive `where` clauses.
      query.where((t) => t.isArchived.equals(false));
    }

    return query.watch();
  }

  /// Null while no live, unarchived row has [id]: unlike [watchAccounts], archived rows have no opt-in here.
  Stream<AccountRow?> watchAccount(String ownerId, String id) {
    return (select(accountsTable)..where((t) => t.id.equals(id) & t.ownerId.equals(ownerId) & t.deletedAt.isNull() & t.isArchived.equals(false))).watchSingleOrNull();
  }

  /// The one read that includes tombstones, so a caller can tell a deleted row from one that never existed.
  Future<AccountRow?> findById(String id) => (select(accountsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertAccount(AccountsTableCompanion row) => into(accountsTable).insert(row);

  /// Never bumps `version`: the server does, and a client-bumped base would make every later edit conflict.
  Future<int> updateAccount(String id, {required int baseVersion, required AccountsTableCompanion patch, required int now}) {
    // Editing a tombstone would move its `updated_at` and resurrect it at the next sync.
    return (update(accountsTable)..where((t) => t.id.equals(id) & t.version.equals(baseVersion) & t.deletedAt.isNull())).write(
      patch.copyWith(updatedAt: Value(now)),
    );
  }

  Future<int> archive(String id, {required int now}) => _setArchived(id, archived: true, now: now);

  Future<int> unarchive(String id, {required int now}) => _setArchived(id, archived: false, now: now);

  /// Moves `updated_at` too, or the delta pull never sees the delete.
  Future<int> softDelete(String id, {required int now}) {
    return (update(accountsTable)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
      AccountsTableCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<int> _setArchived(String id, {required bool archived, required int now}) {
    return (update(accountsTable)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
      AccountsTableCompanion(isArchived: Value(archived), updatedAt: Value(now)),
    );
  }
}
