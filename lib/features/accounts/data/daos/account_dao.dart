import 'package:drift/drift.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/features/accounts/data/tables/accounts_table.dart';

part 'account_dao.g.dart';

/// Row-level access to `accounts` (W2 T4) — the first DAO in the app, so the decisions below are the ones `CategoryDao` (W3 T5) and `TransactionDao`
/// (W5 T4) copy rather than re-argue.
///
/// **What a DAO owns, and what it does not.** This type owns row integrity: the columns §6 demands, the `deleted_at IS NULL` filter golden rule 5 requires
/// of every read, and the `updated_at` stamp W12's pull cursor is built on. It does not own mapping, validation or the outbox — those belong to the
/// repository at T6 (§12.2), which is also the layer that wraps a write and its `sync_mutations` row in one `database.transaction()` at W11 T5. Everything
/// here is stated in rows and companions, never in an `Account` entity: T5 has not written one yet, and the three-model rule (§3) means this class would
/// not accept one even after it exists.
///
/// **Why it holds a `GPClock` rather than taking timestamps from the caller.** `updated_at` is half the pull cursor (`updated_at, id`) of W12 T2, so a
/// mutating path that forgets to move it writes a row that is locally correct and permanently invisible to sync — a bug that surfaces two phases later as
/// "this account never reached the other device". Stamping it in one place makes forgetting it impossible rather than merely discouraged. The
/// counter-argument — that T6 needs the same instant for its outbox payload — is answered by every mutating method returning the row it actually wrote, so
/// the repository builds its mutation from what landed instead of from what it hoped would land.
///
/// **Deliberately not listed in `@DriftDatabase(daos: ...)`.** That annotation generates `late final AccountDao accountDao = AccountDao(this)`, which has
/// nowhere to pass a clock — so the generated getter would only compile if this class fell back to `DateTime.now()`, the one thing the table's own doc
/// forbids. It is constructed explicitly instead, by DI at T6.
@DriftAccessor(tables: [AccountsTable])
class AccountDao extends DatabaseAccessor<GPAppDatabase> with _$AccountDaoMixin {
  AccountDao(super.attachedDatabase, {required GPClock clock}) : _clock = clock;

  final GPClock _clock;

  /// Inserts a new account and returns the row as SQLite stored it.
  ///
  /// [id] is a parameter rather than something minted here: golden rule 4 and ADR-0002 put id generation at the caller, who needs the value before the
  /// insert in order to reference it from the outbox mutation and from whatever else the same transaction writes. A DAO that minted its own id would force
  /// exactly the read-back round trip client-side ids exist to remove.
  ///
  /// Every §6 column is stated explicitly because the table has no SQL defaults — see `accounts_table.dart` for why that is deliberate. `version` starts at
  /// 1 and is never touched by this class again; the server owns it from the first push onwards (§7). `isArchived` is false because an account is never
  /// born archived, and `ownerId` is [localOwnerId] until the W10 sign-in flow claims these rows (ADR-0001), at which point it becomes a parameter fed by
  /// the session rather than a constant.
  Future<AccountRow> insertAccount({
    required String id,
    required String name,
    required String type,
    required String currencyCode,
    required int initialBalance,
  }) {
    // One read of the clock, used for both columns: `created_at == updated_at` on a fresh row is an invariant worth having, and two calls could straddle a
    // millisecond boundary and break it for no reason.
    final now = _clock.nowEpochMillis();

    return into(accountsTable).insertReturning(
      AccountsTableCompanion.insert(
        id: id,
        ownerId: localOwnerId,
        name: name,
        type: type,
        currencyCode: currencyCode,
        initialBalance: initialBalance,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
        version: 1,
      ),
    );
  }

  /// Edits the user-editable columns. Returns the updated row, or null when [id] matches nothing alive.
  ///
  /// A null argument means "leave this column alone", which is why the parameters are optional rather than a companion: a companion would also let a caller
  /// pass `version:`, `ownerId:` or `deletedAt:`, and the whole point of naming the editable set here is that those four are *not* in it.
  ///
  /// **`version` is not incremented.** It is the optimistic-concurrency token of §7: the client pushes it as `baseVersion`, the server runs
  /// `UPDATE ... WHERE version = ?` and hands back the next value. A client that bumped it hopefully would push a base version the server never issued, so
  /// the guarded update would match zero rows and every edit would report a phantom conflict. Only `updated_at` moves here.
  ///
  /// `isArchived` is absent on purpose — it has [archive] and [unarchive], which say what they do at the call site.
  Future<AccountRow?> updateAccount(
    String id, {
    String? name,
    String? type,
    String? currencyCode,
    int? initialBalance,
  }) async {
    // `deleted_at IS NULL` in the WHERE, not just in reads: editing a tombstone would move its `updated_at` and push a resurrected row at the next sync.
    final rows = await (update(accountsTable)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).writeReturning(
      AccountsTableCompanion(
        name: Value.absentIfNull(name),
        type: Value.absentIfNull(type),
        currencyCode: Value.absentIfNull(currencyCode),
        initialBalance: Value.absentIfNull(initialBalance),
        updatedAt: Value(_clock.nowEpochMillis()),
      ),
    );

    return rows.isEmpty ? null : rows.single;
  }

  /// The live account list, re-emitting on every write to the table (ADR-0001, golden rule 1).
  ///
  /// **Archived rows are excluded unless [includeArchived] is set.** Archiving exists to get an account out of the way — out of pickers, out of the list —
  /// while keeping its history and keeping it syncing, so a default that still showed it would leave the feature doing nothing. The composite index
  /// `accounts_owner_id_is_archived` created at T3 is what keeps that filter off a table scan; the archived-inclusive branch is for the settings screen
  /// that un-archives, which is also why [unarchive] exists at all — a default this narrow with no way back would strand rows.
  ///
  /// Ordered by creation, not by name. SQLite's default `BINARY` collation sorts by UTF-8 code point, so "Ăn uống" lands after "Ví", and `NOCASE` only
  /// folds ASCII — locale-aware collation needs ICU, which this app does not ship. A list that claims to be alphabetical and is not is worse than one that
  /// is honestly chronological; sorting for display is W4's problem, in Dart, where the locale is known. `id` breaks ties rather than leaving the order to
  /// SQLite, and it agrees with `created_at` for free because v7 ids are themselves time-ordered (ADR-0002).
  ///
  /// No `.distinct()`. Drift invalidates a stream query per table, so this re-runs on any write to `accounts` even when no visible row moved — measured and
  /// written down in `database_test.dart`. At a handful of accounts that is not worth a filter; `watchTransactions` at W8 is where it starts to be.
  Stream<List<AccountRow>> watchAccounts({bool includeArchived = false}) {
    final query = select(accountsTable)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt), (t) => OrderingTerm.asc(t.id)]);

    if (!includeArchived) {
      // Composed, not replaced: drift ANDs successive `where` clauses.
      query.where((t) => t.isArchived.equals(false));
    }

    return query.watch();
  }

  /// Hides an account from [watchAccounts] without deleting it. Returns the updated row, or null when [id] matches nothing alive.
  ///
  /// Archived is not deleted (§6, golden rule 5): the row keeps its transactions, keeps its balance history and keeps syncing, and `deleted_at` stays null.
  /// Soft delete is a different operation and lands with the repository at T6.
  Future<AccountRow?> archive(String id) => _setArchived(id, archived: true);

  /// Brings an archived account back into [watchAccounts].
  Future<AccountRow?> unarchive(String id) => _setArchived(id, archived: false);

  Future<AccountRow?> _setArchived(String id, {required bool archived}) async {
    final rows = await (update(accountsTable)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).writeReturning(
      // `updated_at` moves, `version` does not — same reasoning as [updateAccount]. Archiving is an ordinary field change as far as sync is concerned.
      AccountsTableCompanion(isArchived: Value(archived), updatedAt: Value(_clock.nowEpochMillis())),
    );

    return rows.isEmpty ? null : rows.single;
  }
}
