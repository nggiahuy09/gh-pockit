import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';

/// What the app can do with accounts, stated in the domain and implemented in `data/` (§3, dependency inversion).
///
/// **Reads are streams, writes are futures, and that split is the architecture rather than a style choice.** Golden rule 1 makes the local DB the source of
/// truth for the UI, so a screen never asks "what are the accounts now?" — it subscribes, and every write that lands anywhere (this device, a background
/// sync, a pull from W12) arrives through the same subscription. A `Future<List<Account>>` read would be a snapshot that goes stale the moment a sync
/// applies, and the caller would have to know to re-fetch, which is the API-driven-UI anti-pattern (§12.1) wearing a repository's clothes.
///
/// **No `ownerId` parameter anywhere.** `AccountDao` requires one on every query and it is right to; the repository is the layer that *knows* it — the
/// `localOwnerId` sentinel today, the session uid once auth lands at W10. Threading it through the domain would mean a `BLoC` holding an owner id, and then
/// a screen, and the day one of them passes the wrong one is the day a shared device shows another user's rows.
///
/// **Not a pass-through (§12.2).** The implementation at T6 owns what the DAO deliberately does not: minting the id (`GPUuidGenerator`, golden rule 4),
/// reading `GPClock` once per operation, mapping row ↔ entity, and — from W7 — writing the outbox mutation inside the *same* transaction as the entity
/// (golden rule 3). None of that is visible here, which is the point: the domain states the capability, the data layer owns the policy.
///
/// **Failures, and which ones a caller must expect.** Every write returns `GPResult` (ADR-0006):
///
/// - [GPValidationFailure] — a domain rule said no, with a code naming the field. Only from the two methods that take user input.
/// - [GPConflictFailure] — the row moved on since this entity was read (§7). Only from [updateAccount], which is the only guarded write.
/// - [GPDatabaseFailure] — the local DB refused. Possible from every method, and louder than it looks: there is no remote copy to fall back to.
///
/// Notably *not* here: a network failure. Nothing on this interface talks to a server — a write lands locally and the sync engine pushes it later, so being
/// offline is not an error condition and there is no `bool isOnline` deciding anything (§12.5).
abstract class AccountRepository {
  const AccountRepository();

  /// The live account list, re-emitting on every change to the underlying table.
  ///
  /// Archived accounts are excluded unless [includeArchived] is set — archiving exists to get an account out of the way, so a default that still showed it
  /// would leave the feature doing nothing. The opt-in branch is for the screen that un-archives.
  ///
  /// Ordered by creation, not alphabetically: SQLite's `BINARY` collation sorts by code point, so "Ăn uống" would land after "Ví", and locale-aware
  /// collation needs ICU this app does not ship. Sorting for display happens in Dart, where the locale is known.
  ///
  /// Errors arrive on the stream's error channel rather than wrapped in a `GPResult` per emission. Unwrapping in every widget would make the common path —
  /// there are accounts, render them — pay for the rare one, and `BLoC` already routes `onError` into a state; that is where the error UI (§11) is built.
  Stream<List<Account>> watchAccounts({bool includeArchived = false});

  /// One account, live. Emits null once it is deleted, which is what a detail screen needs in order to pop itself rather than render a stale copy.
  Stream<Account?> watchAccount(String id);

  /// Creates an account and returns it as persisted.
  ///
  /// Takes fields rather than an [Account] because the caller cannot build one: the id comes from `GPUuidGenerator` and the timestamps from `GPClock`, both
  /// of which live behind this interface. That also means a `BLoC` cannot accidentally mint an id itself and desynchronise it from the outbox row.
  ///
  /// [initialBalance] carries its own currency, so there is no separate `currencyCode` argument to get out of step with it.
  Future<GPResult<Account>> createAccount({required String name, required AccountType type, required Money initialBalance});

  /// Applies [account] to storage, guarded on its [Account.version], and returns the stored result with a fresh `updatedAt`.
  ///
  /// A [GPConflictFailure] here is an ordinary outcome, not a crash: the row was changed elsewhere between the read and this call. The caller has the local
  /// and remote version numbers and can offer the user a reload — which is why this is a return value and not a thrown exception (ADR-0006).
  Future<GPResult<Account>> updateAccount(Account account);

  /// Hides an account from [watchAccounts] while keeping its history and its sync.
  ///
  /// Unguarded by version, unlike [updateAccount]: archiving is idempotent, so a stale version costs nothing, and refusing a user's "hide this" because a
  /// rename landed a moment earlier would be a conflict invented for no benefit. Takes an id rather than an entity for the same reason.
  Future<GPResult<void>> archiveAccount(String id);

  /// Brings an archived account back into [watchAccounts].
  Future<GPResult<void>> unarchiveAccount(String id);

  /// Soft-deletes: stamps `deleted_at` (golden rule 5). The row stays so the server can learn it is gone; a hard delete would be a deletion no other device
  /// ever hears about.
  ///
  /// Deleting an account with transactions is a decision W4 has to make — cascade, block, or orphan — and this method does not pretend to have made it.
  Future<GPResult<void>> deleteAccount(String id);
}
