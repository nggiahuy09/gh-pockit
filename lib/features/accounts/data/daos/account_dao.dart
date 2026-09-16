import 'package:drift/drift.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/features/accounts/data/tables/accounts_table.dart';

part 'account_dao.g.dart';

/// Row-level access to `accounts` (W2 T4) — the first DAO in the app, written to the shape `docs/patterns/local-storage-with-drift.md` §6.2 already
/// prescribes, so `CategoryDao` (W3 T5) and `TransactionDao` (W5 T4) copy one design rather than three.
///
/// **It speaks SQL and rows, and holds no policy**: no clock, no UUIDs, no outbox, no opinion about whether something should sync. Those live one layer up,
/// in the repository at T6 (§12.2). Two consequences that look like awkwardness and are not:
///
/// - **`now` is a required argument on every mutating method.** The repository reads `GPClock` once per operation and passes the same instant here and into
///   the `sync_mutations` row it writes in the same transaction (golden rule 3) — so the entity and the mutation describe the same moment. A DAO that read
///   its own clock would produce two instants inside one transaction and no way to reconcile them. Making it required is also what stops `updated_at` from
///   being forgotten: forget it and the code does not compile, rather than writing a row that is locally correct and permanently invisible to the pull
///   cursor of W12 T2.
/// - **Writes take a companion the mapper built**, not a list of fields. `AccountMapper` at T6 is the one place that knows how an `Account` becomes a row,
///   and duplicating that knowledge in a parameter list here is the three-model rule (§3) leaking.
///
/// **Deliberately not listed in `@DriftDatabase(daos: ...)`.** That generates `late final AccountDao accountDao = AccountDao(this)`, a second DAO instance
/// separate from the one DI hands the repository. Drift resolves a transaction by comparing `attachedDatabase`, so two instances are survivable — but two
/// ways to reach the same DAO is not, and the pattern doc's trap table names a foreign DAO committing outside your transaction as the failure mode. It is
/// constructed once, by DI, at T6.
@DriftAccessor(tables: [AccountsTable])
class AccountDao extends DatabaseAccessor<GPAppDatabase> with _$AccountDaoMixin {
  // `super.attachedDatabase`, not `super.db`: `matching_super_parameters` wants the name drift generated.
  AccountDao(super.attachedDatabase);

  /// The live account list, re-emitting on every write to the table (ADR-0001, golden rule 1).
  ///
  /// **[ownerId] is required, not implied.** Until W10 every row carries `localOwnerId` and the filter changes nothing a user could see, which is exactly
  /// why it has to be written now: adding it after auth lands means auditing every query for the one that was never scoped, and the symptom of missing it
  /// is one account's rows showing up under another account on a shared device. It is also what makes the index earn its keep — `accounts_owner_id_is_archived`
  /// is keyed `(owner_id, is_archived)`, so a query filtering only on `is_archived` can scan the index but never seek into it.
  ///
  /// **Archived rows are excluded unless [includeArchived] is set.** Archiving exists to get an account out of the way — out of pickers, out of the list —
  /// while keeping its history and keeping it syncing, so a default that still showed it would leave the feature doing nothing. The opt-in branch is for
  /// the screen that un-archives, which is also why [unarchive] exists at all: a default this narrow with no way back would strand rows.
  ///
  /// Soft-deleted rows are filtered here, once, so no caller can forget — the pattern doc names that the most common source of "I deleted it and it came
  /// back".
  ///
  /// Ordered by creation, not by name. SQLite's default `BINARY` collation sorts by UTF-8 code point, so "Ăn uống" lands after "Ví", and `NOCASE` only
  /// folds ASCII — locale-aware collation needs ICU, which this app does not ship. A list that claims to be alphabetical and is not is worse than one that
  /// is honestly chronological; sorting for display is W4's problem, in Dart, where the locale is known. `id` breaks ties rather than leaving the order to
  /// SQLite, and it agrees with `created_at` for free because v7 ids are themselves time-ordered (ADR-0002).
  ///
  /// No `.distinct()`. Drift invalidates a stream query per table, so this re-runs on any write to `accounts` even when no visible row moved — measured and
  /// written down in `database_test.dart`. At a handful of accounts that is not worth a filter; `watchTransactions` at W8 is where it starts to be.
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

  /// One row by id, tombstone included.
  ///
  /// The one read that does **not** filter `deleted_at IS NULL`, and the exception is load bearing: `RemoteChangeApplier` at W13 has to find a row it
  /// already soft-deleted in order to reconcile it against the server's tombstone. A lookup that hid it would make the applier insert a duplicate.
  Future<AccountRow?> findById(String id) => (select(accountsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Inserts a row the mapper built.
  ///
  /// No `insertReturning`: the caller already holds every value it wrote — it minted the id (golden rule 4, ADR-0002) and the instant — so reading the row
  /// back would be a round trip to learn what it just said.
  Future<void> insertAccount(AccountsTableCompanion row) => into(accountsTable).insert(row);

  /// Applies [patch] to a live row, guarded on [baseVersion]. Returns the number of rows written — **0 means the row moved under us**, which is the whole
  /// point of the guard and the local half of the optimistic-concurrency scheme in §7.
  ///
  /// `version` itself is never written here. It is the server's: the client pushes it as `baseVersion`, the server runs `UPDATE ... WHERE version = ?` and
  /// hands back the next value. A client that bumped it hopefully would push a base version the server never issued, so the guarded update would match zero
  /// rows and every edit would report a conflict that is not one.
  ///
  /// [now] is stamped onto `updated_at` here rather than trusted to [patch], so a caller cannot build a patch that silently skips the pull cursor.
  Future<int> updateAccount(String id, {required int baseVersion, required AccountsTableCompanion patch, required int now}) {
    // `deleted_at IS NULL` in the WHERE, not just in reads: editing a tombstone would move its `updated_at` and push a resurrected row at the next sync.
    return (update(accountsTable)..where((t) => t.id.equals(id) & t.version.equals(baseVersion) & t.deletedAt.isNull())).write(
      patch.copyWith(updatedAt: Value(now)),
    );
  }

  /// Hides an account from [watchAccounts] without deleting it. Returns the number of rows written; 0 means no live row with that id.
  ///
  /// Archived is not deleted (§6, golden rule 5): the row keeps its transactions, keeps its history and keeps syncing, and `deleted_at` stays null. Soft
  /// delete is a different operation and lands with the repository at T6.
  ///
  /// Unguarded by `version`, unlike [updateAccount]. Archiving is idempotent — the second call writes the value already there — so a stale base version
  /// costs nothing, and failing a user's "hide this" because a sync landed a rename a moment earlier would be a conflict invented for no benefit.
  Future<int> archive(String id, {required int now}) => _setArchived(id, archived: true, now: now);

  /// Brings an archived account back into [watchAccounts].
  Future<int> unarchive(String id, {required int now}) => _setArchived(id, archived: false, now: now);

  Future<int> _setArchived(String id, {required bool archived, required int now}) {
    return (update(accountsTable)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
      // `updated_at` moves, `version` does not — same reasoning as [updateAccount]. Archiving is an ordinary field change as far as sync is concerned.
      AccountsTableCompanion(isArchived: Value(archived), updatedAt: Value(now)),
    );
  }
}
