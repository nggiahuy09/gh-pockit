import 'package:drift/drift.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/features/accounts/data/tables/accounts_table.dart';
import 'package:ghpockit/features/transactions/data/tables/transactions_table.dart';
import 'package:meta/meta.dart';

part 'transaction_dao.g.dart';

/// Row-level access to `transactions` (W4 T5) — the third DAO, on the shape `AccountDao` set and `docs/patterns/local-storage-with-drift.md` §6.2
/// prescribes: SQL and rows only, no clock, no ids, no outbox, and no domain type anywhere in a signature. `TransactionRepositoryImpl` (W4 T6) maps a
/// `TransactionQuery` onto the primitives below and the rows back into entities.
///
/// The two things `AccountDao` explains at length hold here unchanged and are not re-argued: `now` is a required argument on every write, so the
/// repository's one reading of `GPClock` lands everywhere its operation writes; and this DAO is **not** listed in `@DriftDatabase(daos: ...)`, so DI
/// constructs exactly one instance at T6.
///
/// What is new is one column: **every local write stamps `sync_status` to [pendingSyncStatus]** (ADR-0009), overriding whatever the companion carried —
/// the same way `AccountDao.updateAccount` stamps `updated_at` rather than trusting the patch. A write that forgot it would be a local change the sync
/// engine believes it has already pushed.
///
/// [liveAccountCurrency] is the one read that leaves this table, and it is here on purpose: ADR-0010 has the repository check the account inside the write's
/// own transaction, and a lookup through this DAO joins that transaction the way `AccountDao` would, without a second feature's DAO in the repository.
/// [hasLiveTransactions] is the one statement written as raw SQL, and its doc says which character made that necessary.
@DriftAccessor(tables: [TransactionsTable, AccountsTable])
class TransactionDao extends DatabaseAccessor<GPAppDatabase> with _$TransactionDaoMixin {
  // `super.attachedDatabase`, not `super.db`: `matching_super_parameters` wants the name drift generated.
  TransactionDao(super.attachedDatabase);

  /// The only sync state a local write can produce (ADR-0009). `synced` is written by the sync engine from W13, through a path of its own, and it is not
  /// declared until then.
  ///
  /// Public because `TransactionMapper.toInsert` has to pass *a* value — `TransactionsTableCompanion.insert` requires one — and passing this one keeps the
  /// literal in one place. It is overwritten here regardless.
  static const String pendingSyncStatus = 'pending';

  /// The live window of transactions for [ownerId], newest first, re-emitting on every write to the table (golden rule 1).
  ///
  /// Every filter is optional and they AND together; `null` means "do not filter on this". An **empty** set is not normalised here: it becomes `IN ()`,
  /// which SQLite reads as false, so it matches nothing — the plain SQL meaning. `TransactionQuery` never sends one (it turns an empty set into no filter),
  /// so the DAO has no need to guess on the domain's behalf.
  ///
  /// - [accountIds] match **either side of a transfer** — `account_id` or `destination_account_id` (ADR-0011).
  /// - [types] are storage values (`'expense'`, `'income'`, `'transfer'`), not `TransactionType`: the DAO does not import the domain.
  /// - [fromMillis] is inclusive and [toMillis] exclusive, both epoch millis UTC — `[from, to)`, so consecutive months never share a row.
  ///
  /// Soft-deleted rows are filtered here, once, so no caller can forget; the order is total, `occurred_at DESC, id DESC`, so rows cannot swap places
  /// between emissions; and [limit] caps the window, which only ever grows (ADR-0011).
  ///
  /// **The account filter is an `OR`, and no index serves it in order.** Each side has its own index, but not both at once, so SQLite picks by cost
  /// between two plans with different bills: walk the owner index newest-first and filter — no sort, but a rarely used account reads far back through
  /// every other row (the pick on the machine this was written on) — or merge the two account indexes and sort everything that matched.
  /// `transaction_dao_test.dart` accepts either and forbids a full scan. A `UNION ALL` of the two sides — each read straight off its own index, never
  /// overlapping because a transfer cannot name one account twice — serves it in order, and waits for W8 to measure whether it is needed.
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

  /// The statement [watchTransactions] watches — exposed so a test can run `EXPLAIN QUERY PLAN` on the SQL this DAO really sends, rather than on a copy of
  /// it written by hand that would keep passing after this one changed.
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

  /// One live row by id, **null once it is gone** — soft-deleted, or never there. What the edit screen of W6 T4 subscribes to, so it can close itself
  /// rather than edit a tombstone.
  ///
  /// Scoped by [ownerId] even though an id is already unique, for the W10 reason `AccountDao.watchAccount` gives.
  Stream<TransactionRow?> watchTransaction(String ownerId, String id) {
    return (select(transactionsTable)..where((t) => t.id.equals(id) & t.ownerId.equals(ownerId) & t.deletedAt.isNull())).watchSingleOrNull();
  }

  /// One row by id, **tombstone included** — the one read that does not filter `deleted_at IS NULL`.
  ///
  /// Load bearing twice: `TransactionRepositoryImpl.updateTransaction` reads it inside its transaction to tell a conflict from a row that is gone, and the
  /// applier of W14 needs to find a row it already soft-deleted before it can reconcile the server's copy.
  Future<TransactionRow?> findById(String id) => (select(transactionsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// The currency of [ownerId]'s account [accountId] while it is live, or null when there is no such account or it is soft-deleted (ADR-0010).
  ///
  /// Archived counts as live: an old transaction on an archived account must stay editable, and keeping archived accounts out of the picker is presentation's
  /// job. Owner-scoped because "the account belongs to the owner" is part of the rule — a foreign key only proves the row exists.
  ///
  /// One column rather than the whole row: the repository needs to know whether the account is there and what currency it keeps, and nothing else.
  Future<String?> liveAccountCurrency(String ownerId, String accountId) async {
    final query = selectOnly(accountsTable)
      ..addColumns([accountsTable.currencyCode])
      ..where(accountsTable.id.equals(accountId) & accountsTable.ownerId.equals(ownerId) & accountsTable.deletedAt.isNull());

    final row = await query.getSingleOrNull();
    return row?.read(accountsTable.currencyCode);
  }

  /// Whether any live transaction of [ownerId] touches [accountId], **on either side of a transfer** — the question `DeleteAccountUseCase` asks before it
  /// lets an account go (ADR-0010). A tombstone does not count; a transaction on an archived account does, because archiving keeps the history.
  ///
  /// **Raw SQL, for one character: the `+` in `+owner_id`.** Built with the query builder, the owner term is an equality on the leading column of the owner
  /// index, and SQLite — with no statistics, it guesses that any equality narrows to a handful of rows — prefers that index to the two account ones. The
  /// plan then walks every transaction the owner has, filtering for the account. `EXISTS` stops at the first match, so an account that has transactions
  /// answers quickly either way; the walk only reaches the end for an account with **none** — exactly the account this question lets the user delete. A
  /// unary `+` is SQLite's documented way to keep a term out of index selection: the plan becomes one seek into each account index (`MULTI-INDEX OR`),
  /// and the owner is still checked on whatever row is found. `transaction_dao_test.dart` pins that plan on [hasLiveTransactionsSql].
  Future<bool> hasLiveTransactions(String ownerId, String accountId) async {
    final row = await customSelect(hasLiveTransactionsSql, variables: [Variable.withString(ownerId), Variable.withString(accountId)]).getSingle();

    return row.read<bool>('has_live');
  }

  /// The statement [hasLiveTransactions] runs, exposed for the reason [selectTransactions] is: the plan test explains this string, not a copy of it.
  ///
  /// `?1` is the owner and `?2` the account, which is named twice — once per side of a transfer.
  @visibleForTesting
  static const String hasLiveTransactionsSql =
      'SELECT EXISTS (SELECT 1 FROM transactions WHERE +owner_id = ?1 AND deleted_at IS NULL AND (account_id = ?2 OR destination_account_id = ?2)) AS has_live';

  /// Inserts a row the mapper built, with `sync_status` stamped to [pendingSyncStatus] whatever the companion said.
  ///
  /// No `insertReturning`, for the reason `AccountDao.insertAccount` gives: the caller already holds every value it wrote.
  Future<void> insertTransaction(TransactionsTableCompanion row) => into(transactionsTable).insert(row.copyWith(syncStatus: const Value(pendingSyncStatus)));

  /// Applies [patch] to a live row, guarded on [baseVersion]. Returns the number of rows written — **0 means the row moved under us, is a tombstone, or was
  /// never there**, and the repository tells those apart with [findById].
  ///
  /// [now] lands on `updated_at` and `sync_status` goes back to [pendingSyncStatus], both stamped here rather than trusted to [patch]. `version` is never
  /// written — it is the server's, for the reason `AccountDao.updateAccount` gives.
  Future<int> updateTransaction(String id, {required int baseVersion, required TransactionsTableCompanion patch, required int now}) {
    // `deleted_at IS NULL` in the WHERE, not just in reads: editing a tombstone would move its `updated_at` and push a resurrected row at the next sync.
    return (update(transactionsTable)..where((t) => t.id.equals(id) & t.version.equals(baseVersion) & t.deletedAt.isNull())).write(
      patch.copyWith(updatedAt: Value(now), syncStatus: const Value(pendingSyncStatus)),
    );
  }

  /// Stamps the tombstone (golden rule 5). Returns the number of rows written; 0 means there was no live row with that id.
  ///
  /// [now] lands on `deleted_at` and on `updated_at` — the second is what makes the deletion visible to W14's pull — and `sync_status` goes back to
  /// [pendingSyncStatus], because a deletion is a change the server has not heard of yet. Unguarded by version, like `AccountDao.softDelete`.
  Future<int> softDelete(String id, {required int now}) {
    return (update(transactionsTable)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
      TransactionsTableCompanion(deletedAt: Value(now), updatedAt: Value(now), syncStatus: const Value(pendingSyncStatus)),
    );
  }
}
