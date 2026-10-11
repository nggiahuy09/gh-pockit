import 'package:drift/drift.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/features/accounts/data/tables/accounts_table.dart';
import 'package:ghpockit/features/transactions/data/tables/transactions_table.dart';
import 'package:meta/meta.dart';

part 'transaction_dao.g.dart';

/// Every local write stamps `sync_status` to [pendingSyncStatus], whatever the companion carried (ADR-0009): a write that forgot would look already pushed.
@DriftAccessor(tables: [TransactionsTable, AccountsTable])
class TransactionDao extends DatabaseAccessor<GPAppDatabase> with _$TransactionDaoMixin {
  // `super.attachedDatabase`, not `super.db`: `matching_super_parameters` wants the name drift generated.
  TransactionDao(super.attachedDatabase);

  /// Public only because `TransactionMapper.toInsert` must fill the required companion field; every write overwrites it anyway.
  static const String pendingSyncStatus = 'pending';

  /// [accountIds] match either side of a transfer (ADR-0011); [toMillis] is exclusive. An empty set becomes `IN ()` and matches nothing —
  /// `TransactionQuery` never sends one.
  ///
  /// No single index serves the account `OR` in order, so SQLite picks by cost between walking the owner index and merging the two account indexes. The
  /// plan test accepts either and forbids a full scan; a `UNION ALL` of the two sides waits for W8's numbers.
  Stream<List<TransactionRow>> watchTransactions(
    String ownerId, {
    required int limit,
    Set<String>? accountIds,
    Set<String>? categoryIds,
    Set<String>? types,
    int? fromMillis,
    int? toMillis,
  }) => selectTransactions(
    ownerId,
    limit: limit,
    accountIds: accountIds,
    categoryIds: categoryIds,
    types: types,
    fromMillis: fromMillis,
    toMillis: toMillis,
  ).watch();

  /// Exposed so the plan test explains the SQL this DAO really sends, not a hand-written copy.
  @visibleForTesting
  SimpleSelectStatement<$TransactionsTableTable, TransactionRow> selectTransactions(
    String ownerId, {
    required int limit,
    Set<String>? accountIds,
    Set<String>? categoryIds,
    Set<String>? types,
    int? fromMillis,
    int? toMillis,
  }) {
    final query = select(transactionsTable)..where((t) => t.ownerId.equals(ownerId) & t.deletedAt.isNull());

    // Composed, not replaced: drift ANDs successive `where` clauses.
    if (accountIds != null) query.where((t) => t.accountId.isIn(accountIds) | t.destinationAccountId.isIn(accountIds));
    if (categoryIds != null) query.where((t) => t.categoryId.isIn(categoryIds));
    if (types != null) query.where((t) => t.type.isIn(types));
    if (fromMillis != null) query.where((t) => t.occurredAt.isBiggerOrEqualValue(fromMillis));
    if (toMillis != null) query.where((t) => t.occurredAt.isSmallerThanValue(toMillis));

    return query
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt), (t) => OrderingTerm.desc(t.id)])
      ..limit(limit);
  }

  /// Emits null once the row is soft-deleted, so the edit screen can close instead of editing a tombstone.
  Stream<TransactionRow?> watchTransaction(String ownerId, String id) {
    return (select(transactionsTable)..where((t) => t.id.equals(id) & t.ownerId.equals(ownerId) & t.deletedAt.isNull())).watchSingleOrNull();
  }

  /// Tombstones included — the one read that does not filter `deleted_at`, so an update can tell a conflict from a deleted row.
  Future<TransactionRow?> findById(String id) => (select(transactionsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Null when the account is missing, soft-deleted or another owner's. Archived counts as live (ADR-0010).
  Future<String?> liveAccountCurrency(String ownerId, String accountId) async {
    final query = selectOnly(accountsTable)
      ..addColumns([accountsTable.currencyCode])
      ..where(accountsTable.id.equals(accountId) & accountsTable.ownerId.equals(ownerId) & accountsTable.deletedAt.isNull());

    final row = await query.getSingleOrNull();
    return row?.read(accountsTable.currencyCode);
  }

  /// Either side of a transfer. Tombstones do not count; transactions on an archived account do (ADR-0010).
  Future<bool> hasLiveTransactions(String ownerId, String accountId) async {
    final row = await customSelect(hasLiveTransactionsSql, variables: [Variable.withString(ownerId), Variable.withString(accountId)]).getSingle();

    return row.read<bool>('has_live');
  }

  /// Raw SQL for the unary `+` on `owner_id`, which keeps that term out of index selection. Without it SQLite, having no statistics, picks the owner index
  /// and walks the owner's whole history for an account with no transactions — the very account this check lets the user delete. With it the plan is one
  /// seek per account index (`MULTI-INDEX OR`), pinned by the plan test. `?1` is the owner, `?2` the account.
  @visibleForTesting
  static const String hasLiveTransactionsSql =
      'SELECT EXISTS (SELECT 1 FROM transactions WHERE +owner_id = ?1 AND deleted_at IS NULL AND (account_id = ?2 OR destination_account_id = ?2)) AS has_live';

  Future<void> insertTransaction(TransactionsTableCompanion row) => into(transactionsTable).insert(row.copyWith(syncStatus: const Value(pendingSyncStatus)));

  /// Returns the rows written: 0 means a stale [baseVersion], a tombstone or no row, which the repository tells apart with [findById]. Never writes
  /// `version` — it is the server's.
  Future<int> updateTransaction(String id, {required int baseVersion, required TransactionsTableCompanion patch, required int now}) {
    // `deleted_at IS NULL` here too: editing a tombstone would move its `updated_at` and resurrect it at the next sync.
    return (update(transactionsTable)..where((t) => t.id.equals(id) & t.version.equals(baseVersion) & t.deletedAt.isNull())).write(
      patch.copyWith(updatedAt: Value(now), syncStatus: const Value(pendingSyncStatus)),
    );
  }

  /// Unguarded by version. `updated_at` moves with `deleted_at`, which is what makes the deletion visible to the pull (W14).
  Future<int> softDelete(String id, {required int now}) {
    return (update(transactionsTable)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
      TransactionsTableCompanion(deletedAt: Value(now), updatedAt: Value(now), syncStatus: const Value(pendingSyncStatus)),
    );
  }
}
