import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../../core/database/database.dart';
import '../../../accounts/data/tables/accounts_table.dart';
import '../tables/transactions_table.dart';

part 'transaction_dao.g.dart';

/// Every local write stamps `sync_status` to [pendingSyncStatus], whatever the companion carried (ADR-0009): a write that forgot would look already pushed.
@DriftAccessor(tables: [TransactionsTable, AccountsTable])
base class TransactionDao extends DatabaseAccessor<GPAppDatabase> with _$TransactionDaoMixin {
  TransactionDao(super.attachedDatabase);

  /// Public only because `toInsert` must fill the required companion field; every write overwrites it anyway.
  static const pendingSyncStatus = 'pending';

  /// The unary `+` keeps `owner_id` out of index selection: with no statistics SQLite would walk the owner's whole history for an account with no
  /// transactions. With it the plan is one seek per account index, pinned by the plan test. `?1` is the owner, `?2` the account.
  @visibleForTesting
  static const hasLiveTransactionsSql =
      'SELECT EXISTS (SELECT 1 FROM transactions WHERE +owner_id = ?1 AND deleted_at IS NULL AND (account_id = ?2 OR destination_account_id = ?2)) AS has_live';

  /// The four terms of ADR-0009. The other account is not joined, so a deleted account's transfers still count (ADR-0010).
  @visibleForTesting
  static const accountBalancesSql = '''
SELECT a.*,
  a.initial_balance
  + COALESCE((SELECT SUM(CASE t.type WHEN 'income' THEN t.amount_minor WHEN 'expense' THEN -t.amount_minor WHEN 'transfer' THEN -t.amount_minor ELSE 0 END)
              FROM transactions t WHERE t.account_id = a.id AND t.deleted_at IS NULL), 0)
  + COALESCE((SELECT SUM(t.amount_minor)
              FROM transactions t WHERE t.destination_account_id = a.id AND t.type = 'transfer' AND t.deleted_at IS NULL), 0) AS balance_minor
FROM accounts a
WHERE a.owner_id = ?1 AND a.deleted_at IS NULL AND a.is_archived = 0
ORDER BY a.created_at, a.id''';

  /// [accountIds] match either side of a transfer (ADR-0011); [toMillis] is exclusive.
  Stream<List<TransactionRow>> watchTransactions(
    String ownerId, {
    Set<String>? accountIds,
    Set<String>? categoryIds,
    Set<String>? types,
    int? fromMillis,
    required int limit,
    int? toMillis,
  }) => selectTransactions(ownerId, accountIds: accountIds, categoryIds: categoryIds, types: types, fromMillis: fromMillis, limit: limit, toMillis: toMillis).watch();

  /// Exposed so the plan test explains the SQL this DAO really sends.
  @visibleForTesting
  SimpleSelectStatement<$TransactionsTableTable, TransactionRow> selectTransactions(
    String ownerId, {
    Set<String>? accountIds,
    Set<String>? categoryIds,
    Set<String>? types,
    int? fromMillis,
    required int limit,
    int? toMillis,
  }) {
    final query = select(transactionsTable)..where((t) => t.ownerId.equals(ownerId) & t.deletedAt.isNull());

    if (accountIds != null) query.where((t) => t.accountId.isIn(accountIds) | t.destinationAccountId.isIn(accountIds));
    if (categoryIds != null) query.where((t) => t.categoryId.isIn(categoryIds));
    if (types != null) query.where((t) => t.type.isIn(types));
    if (fromMillis != null) query.where((t) => t.occurredAt.isBiggerOrEqualValue(fromMillis));
    if (toMillis != null) query.where((t) => t.occurredAt.isSmallerThanValue(toMillis));

    return query
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt), (t) => OrderingTerm.desc(t.id)])
      ..limit(limit);
  }

  Stream<TransactionRow?> watchTransaction({required String id, required String ownerId}) {
    return (select(transactionsTable)..where((t) => t.id.equals(id) & t.ownerId.equals(ownerId) & t.deletedAt.isNull())).watchSingleOrNull();
  }

  /// The one read that includes tombstones, so an update can tell a conflict from a deleted row.
  Future<TransactionRow?> findById(String id) => (select(transactionsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Null when the account is missing, soft-deleted or another owner's. Archived counts as live (ADR-0010).
  Future<String?> liveAccountCurrency({required String accountId, required String ownerId}) async {
    final query = selectOnly(accountsTable)
      ..addColumns([accountsTable.currencyCode])
      ..where(accountsTable.id.equals(accountId) & accountsTable.ownerId.equals(ownerId) & accountsTable.deletedAt.isNull());

    final row = await query.getSingleOrNull();
    return row?.read(accountsTable.currencyCode);
  }

  Future<bool> hasLiveTransactions({required String accountId, required String ownerId}) async {
    final row = await customSelect(hasLiveTransactionsSql, variables: [Variable.withString(ownerId), Variable.withString(accountId)]).getSingle();

    return row.read<bool>('has_live');
  }

  /// One statement over both tables, so the two cannot disagree, and it re-runs on a write to either (ADR-0019).
  Stream<List<({AccountRow account, int balanceMinor})>> watchAccountBalances(String ownerId) {
    return customSelect(accountBalancesSql, variables: [Variable.withString(ownerId)], readsFrom: {accountsTable, transactionsTable}).watch().map(
      (rows) => [for (final row in rows) (account: accountsTable.map(row.data), balanceMinor: row.read<int>('balance_minor'))],
    );
  }

  Future<void> insertTransaction(TransactionsTableCompanion row) => into(transactionsTable).insert(row.copyWith(syncStatus: const Value(pendingSyncStatus)));

  /// Never writes `version`, the server's. Skips tombstones, whose `updated_at` moving would resurrect them at the next sync.
  Future<int> updateTransaction(String id, {required TransactionsTableCompanion patch, required int baseVersion, required int now}) {
    return (update(transactionsTable)..where((t) => t.id.equals(id) & t.version.equals(baseVersion) & t.deletedAt.isNull())).write(
      patch.copyWith(updatedAt: Value(now), syncStatus: const Value(pendingSyncStatus)),
    );
  }

  /// `updated_at` moves with `deleted_at`, which is what makes the deletion visible to the pull.
  Future<int> softDelete(String id, {required int now}) {
    return (update(transactionsTable)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
      TransactionsTableCompanion(updatedAt: Value(now), deletedAt: Value(now), syncStatus: const Value(pendingSyncStatus)),
    );
  }

  /// The inverse of [softDelete] (ADR-0017).
  Future<int> restore(String id, {required int now}) {
    return (update(transactionsTable)..where((t) => t.id.equals(id) & t.deletedAt.isNotNull())).write(
      TransactionsTableCompanion(updatedAt: Value(now), deletedAt: const Value(null), syncStatus: const Value(pendingSyncStatus)),
    );
  }
}
