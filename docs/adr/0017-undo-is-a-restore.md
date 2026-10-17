# ADR 0017 — Undo is a restore: a delete is written at once and taken back by clearing `deleted_at`

## Status

Accepted — 2026-10-13 (W6 T4). Applies to transactions, the first entity a user
can delete from the UI; a later delete with an undo (category, account) follows
it.

_Amended 2026-10-13:_ a swipe asks before it deletes (the user's call, after
trying it); the form's Delete still does not. See "A swipe asks first" below.

## Context

W6 T4 puts delete on screen, with an undo in a snackbar. The soft delete itself
is old (golden rule 5; `deleteTransaction` since W4): it stamps `deleted_at`,
and every read filters it out. What is new is taking one back. Two ways were on
the table (the user chose on 2026-10-13):

1. **Write at once; Undo restores.** The delete is a write like any other. Undo
   is a second write that clears `deleted_at`.
2. **Hold the write until the snackbar closes.** The row is hidden from the
   list at once, and the delete is written only if the snackbar times out
   without an undo.

## Decision

**Write at once; Undo restores.**

- `TransactionRepository.restoreTransaction(id)`, inside one database
  transaction: reads the row, tombstones included; refuses with
  `GPNotFoundFailure` unless it is one of the owner's tombstones; then checks
  the account rules of ADR-0010 (rules 1–2) on the row's own columns, as a
  create would. An account deleted in the meantime is possible — the delete
  may have left it empty, which is when `DeleteAccountUseCase` lets it go — and
  refuses the restore. There is no category rule: coming back files nothing
  new, the same reason `UpdateTransactionUseCase` skips an unchanged filing. Not
  guarded by version, like the delete.
- `TransactionDao.restore` sets `deleted_at = NULL`, moves `updated_at` and
  stamps `pending`, on a tombstone only, and never touches `version`.
- `DeleteTransactionUseCase` and `RestoreTransactionUseCase` forward one call
  each (ADR-0013).
- **A swipe asks first; the form's Delete does not.** A scroll that drifts
  sideways can swipe a row away, so the swipe opens a dialog naming the row by
  its title and amount, and so does the screen reader's action that stands in
  for it. Cancel or a tap outside slides the row back, with nothing written.
  The trash icon in the edit form is a deliberate tap, on a screen already
  showing that one transaction, so it deletes at once. The undo follows every
  delete either way: the dialog guards the gesture, the undo the decision.
- **One undo at a time.** A new delete replaces the snackbar, and only the
  latest delete can be taken back.
- **Two ways in.** Swiping a list row towards the start, with the same delete
  offered to a screen reader as the row's custom action; and Delete in the edit
  form's app bar. The form pops with `TransactionFormOutcome.deleted`, and the
  list shows the snackbar. A form opened cold from a deep link has no list under
  it, so its delete stands with no undo offered.
- **The swipe writes before the row leaves.** The dialog and then the delete
  run in `confirmDismiss`, so the row slides away only once it is written, and
  the list's next snapshot is what takes it out. A cancelled or refused delete
  slides it back.
- The shell lifts every snackbar above the floating dock (`AppShell` sets the
  snackbar theme's inset), so the undo never sits under it.

**Sync, decided now for P4.** Each write is a mutation: the delete an
`operation: delete`, the restore an update clearing `deleted_at`. When the
restore is enqueued before the delete was pushed, the two cancel out and
nothing goes up (coalescing, W12). Otherwise the server must accept clearing
`deleted_at` on a tombstone (W10's schema and RLS). A tombstone is not final
until it is garbage-collected (blueprint §27, 30 days), and an undo comes
seconds after its delete. The restore moves `updated_at`, so other devices'
pulls see the row come back.

## Consequences

Positive:

- The list is the database at every moment (golden rule 1). Nothing is held in
  memory, so nothing is lost when the app is killed with the snackbar up: the
  transaction is deleted, which is what the user saw.
- Balances (T6) and the list agree throughout. Neither counts a row the other
  hides.
- The restore holds the same account rules as a new row, so an undo can never
  put a transaction under an account that is gone.

Negative:

- One more repository method, DAO write and use case.
- A swipe costs a second tap, and asks twice in effect: once before, once in
  the undo after.
- A delete that was already pushed, then undone, costs two mutations, and the
  server has to allow a tombstone back.
- An undo can be refused (the account is gone), and the user then reads a
  message instead of getting the row back.
- No undo after a delete from a form opened cold.
- The restore does not check whose delete it is taking back: in P4 a pull
  could land another device's delete of the same row between ours and the
  undo, and the undo would bring it back. Accepted, because the user asked for
  that row. Guarding on the delete's own `deleted_at` needs the delete to hand
  its stamp back; revisit at W12.

## Alternatives rejected

**Hold the write until the snackbar closes.** No restore API and one mutation.
But the list would hide a row the database still holds, against golden rule 1.
A kill or a navigation during the window would lose the delete unless it is
flushed on dispose, balances would count the row while the list does not show
it, and the list bloc would need a "pending delete" filter on top of its query.

**No dialog at all, the undo alone** (this ADR as first written). No extra tap,
but a sideways drift during a scroll deletes a row the user never meant to
touch, and the undo only helps if they notice within four seconds.

**A dialog in place of the undo.** One mutation and no restore API, but it
guards only the gesture: a delete confirmed and then regretted has no way back.

**A dialog on the form's Delete too.** An extra tap on a choice the user made
on purpose, on the screen for that one transaction.

**Undo by re-creating the transaction.** A new id: the row's identity and sync
history would break, and in P4 the server would see a delete and an unrelated
insert.
