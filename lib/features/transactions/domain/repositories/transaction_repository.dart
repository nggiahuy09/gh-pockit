import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_list_snapshot.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

/// What the app can do with transactions (W4 T4), stated in the domain and implemented in `data/` at W4 T6.
///
/// The shape is `AccountRepository`'s — reads are streams, writes return [GPResult], and no `ownerId` appears anywhere — and that interface's doc makes the
/// case for each of those; it is not repeated here. What is different is scale, and the one read that scale reshaped: [watchTransactions] emits a
/// [TransactionListSnapshot] instead of a bare list, and takes a [TransactionQuery] with a limit instead of returning everything (ADR-0011).
///
/// **Not a pass-through (§12.2).** The implementation owns everything this interface does not say: minting the id (`GPUuidGenerator.v7`, golden rule 4),
/// reading `GPClock` once per operation, the owner, mapping row ↔ entity, setting `sync_status` to `pending` on every write (ADR-0009), and the two rules
/// that need another row — the account (and a transfer's destination) is still there, and the amount is in its currency — checked **inside** the write's
/// own transaction, so a background sync cannot invalidate them between check and write (ADR-0010). From W12 T5 the outbox mutation joins that transaction.
///
/// **Failures, and which ones a caller must expect** (ADR-0006):
///
/// - [GPValidationFailure] — a rule said no. The entity's own rules (a positive amount, a transfer's destination, a note's length) from
///   [createTransaction]; and from both writes, an amount whose currency is not its account's, or a transfer between accounts of two currencies (ADR-0010).
/// - [GPNotFoundFailure] — no live row with that id: the transaction for [updateTransaction] and [deleteTransaction], or the account or destination for
///   either write. Archived accounts are live; only a deleted one is gone.
/// - [GPConflictFailure] — only from [updateTransaction], the one guarded write (§7).
/// - [GPDatabaseFailure] — the local database refused, from every method. Includes a `category_id` that names no row at all, which the foreign key refuses;
///   whether a category that does exist is live and of the right kind is the use cases' rule, not this interface's (ADR-0010).
///
/// Not here: a network failure, for the reason `AccountRepository` gives. Not here either: "does this account have transactions?" —
/// `DeleteAccountUseCase` needs it, and it arrives with that rule at W4 flex rather than ahead of it (§12.11).
abstract class TransactionRepository {
  const TransactionRepository();

  /// The live window of transactions [query] describes, re-emitting on every write to the table (drift invalidates per table, so an unrelated write
  /// re-runs it too — the snapshot's equality is what keeps that from rebuilding the screen).
  ///
  /// Ordered `occurred_at DESC, id DESC`. Account ids in [query] match either side of a transfer, and transactions on a soft-deleted account or under a
  /// soft-deleted category are still returned: sync can produce them whatever the write path does, so readers tolerate them (ADR-0010).
  ///
  /// **A row that will not map is not an error.** It is counted in [TransactionListSnapshot.unreadableCount] and logged by id and reason, and the rest of
  /// the list is emitted (ADR-0011). What does arrive on the error channel is the query itself failing, and then the error object is always a
  /// [GPDatabaseFailure] — never a raw exception, so an `onError` handler reads `failure.message(l10n)` with no type test, as it does for accounts.
  Stream<TransactionListSnapshot> watchTransactions(TransactionQuery query);

  /// One transaction, live — what the edit screen of W6 T4 subscribes to. Emits null once it is deleted, so the screen can close itself instead of editing
  /// a tombstone.
  ///
  /// A row that will not map *is* an error here, on the error channel as a [GPDatabaseFailure]: there is no partial answer for one row.
  Stream<TransactionEntity?> watchTransaction(String id);

  /// Creates a transaction and returns it as persisted.
  ///
  /// Takes fields rather than a [TransactionEntity] for the reason `AccountRepository.createAccount` does: the caller cannot build one, because the id and
  /// the timestamps come from behind this interface. [amount] carries its currency, which must be [accountId]'s.
  Future<GPResult<TransactionEntity>> createTransaction({
    required TransactionType type,
    required String accountId,
    required Money amount,
    required DateTime occurredAt,
    String? destinationAccountId,
    String? categoryId,
    String? note,
  });

  /// Applies [transaction] to storage, guarded on its [TransactionEntity.version], and returns the stored result with a fresh `updatedAt`.
  ///
  /// Takes the whole entity because the caller already holds one and `TransactionEntity.update` has already applied the entity's rules. The account rules
  /// run again here, inside the write — the account may have changed since the form opened.
  Future<GPResult<TransactionEntity>> updateTransaction(TransactionEntity transaction);

  /// Soft-deletes: stamps `deleted_at` (golden rule 5), so the server can learn the transaction is gone.
  ///
  /// Unguarded by version, like `AccountRepository.deleteAccount`: deleting is terminal, so a stale version costs nothing, and refusing because an edit
  /// landed a moment earlier would only make the user press delete twice. Deleting a transaction has no rule beyond this, which is why no use case wraps
  /// it (ADR-0010).
  Future<GPResult<void>> deleteTransaction(String id);
}
