# ADR 0042 — Sign-out is refused while anything is unsynced, then wipes the device's copy

## Status

Accepted — 2026-11-24 (W12 T6, started early). This writes down decisions C and D of the W12 plan, which you chose on 2026-11-15, plus the
order of the steps. No schema change.

## Context

- Blueprint §33 recommends "logout wipes account-local data, then sync again after sign-in". T6 asks for the local data and the session
  to be cleared, children deleted before parents for the foreign keys, and sync cancelled.
- Before push exists (W14), no row has ever reached the server. Wiping on sign-out would delete the only copy of everything.
- Only `transactions` has a `sync_status`. Accounts and categories carry no sync state until the outbox (W13).
- The device has one owner (ADR-0040). A sign-out is what gives the device back to `'local'`.
- `settings` holds device preferences (the language), plus the owner and the session marker (ADR-0039).

## Decision

1. **Refused while anything is unsynced** (decision C). `countUnsyncedChanges` counts, for the device owner:
   - every account;
   - every category the user made, renamed or deleted;
   - every pending transaction.

   Deleted rows count, because the deletion has to sync too. Untouched seeded categories do not: every device seeds the same ones.
   - With a count above zero, the dialog explains and offers no way through ("Còn N thay đổi chưa được sao lưu…", one button, Đã hiểu).
   - With zero, it asks for confirmation (a danger dialog).
   - `SignOutUseCase` checks the count again itself, so no caller can skip it.
   - **Until P4 every account counts**, so a device with any data cannot sign out. That is the intended trade: losing data is worse
     than being stuck signed in. The outbox (W13) will make the count exact. Once push exists (W14), this becomes a confirmation that
     shows the count.
2. **In this order:** count, then wipe the device's copy, then end the session.
   - If the wipe fails, the user is still signed in and nothing is lost.
   - The session's end always succeeds locally (ADR-0038), and the keeper deletes the kept session on `signedOut` (ADR-0039).
3. **The wipe is one transaction** (`DeviceOwnerDao.wipeOwnerRows`):
   - `transactions`, then `categories`, then `accounts` are hard-deleted, children first for the foreign keys;
   - the `owner.id` row is deleted too.

   This is the device's copy going, not a delete of the entities. The server keeps them, and nothing is enqueued, so golden rule 5 does
   not apply.
4. **`settings` stays** (decision D): the language, and later the appearance mode. Only the owner goes. The session marker may stay too,
   since a marker with no session restores nothing.
5. **Afterwards the app is usable at once**, as signed out (decision E):
   - the owner is adopted back as `'local'`, so open lists switch rather than go stale (ADR-0040);
   - the default categories are reseeded for `'local'`. A reseed that fails is logged, and the next launch seeds them.
6. **An unclaimed device (`'local'`) is never wiped.** Its rows belong to no account.
7. **Cancelling sync is a no-op** until a sync engine exists. W14 adds it as the first step.
8. **UI:** a Sign out button on the signed-in sync card in Settings, run by `SignOutBloc`:
   - states: idle, checking, blocked(count), confirming, in progress, done and error;
   - the dialogs and the "Đã đăng xuất." snackbar come from Settings' listener;
   - the bloc's use cases are `late`, so the listener can build it on every visit without a backend.

## Consequences

Positive:

- No sign-out can delete data that exists nowhere else.
- One transaction: a failed wipe leaves the device exactly as it was, still signed in.
- After a sign-out the app is a clean local-only app with the language kept, ready for the next user or for the same user to sign back
  in and pull (P4).

Negative:

- **Until push exists, sign-out works only on a device with no data.** On the simulator, with 5 accounts and 105 transactions, it is
  refused with "Còn 110 thay đổi". The confirm path is covered by tests, not by a device run.
- **The count is approximate until the outbox exists:** it treats every account as unsynced. It cannot be too low, only too high.
- **A device whose session ended by itself shows Sign in, not Sign out.** Its data still belongs to the previous user (ADR-0040). The
  previous user can sign back in, or wait for sign-out to come back. Signing in as another account is refused until then.
- **Hard delete on sign-out** is a second place, after the claim's duplicate seed, where a synced table loses rows outside
  `deleted_at`. It is local-only by construction.

## How it is validated

- `device_owner_repository_impl_test.dart`, on a real in-memory database:
  - the count: untouched seeds 0; offline use 7 (2 accounts, 1 own category, 4 transactions with one deleted); a renamed seed 1; only
    the owner's rows;
  - the release: the owner's rows gone, the language setting kept, `owner.id` gone, the owner back to `'local'`, defaults reseeded, an
    open list emptied, `PRAGMA foreign_key_check` clean;
  - an unclaimed device kept;
  - a refused delete rolls everything back and keeps the owner.
- `SignOutUseCase`: wipe then sign out; refused when unsynced, with nothing wiped; a failed wipe keeps the session; a failed count
  refuses.
- `SignOutBloc`: blocked with the count, confirm, cancel, a stray confirm ignored, an error that can be retried.
- `auth_routes_test.dart` through the whole app: a blocked sign-out explained, a confirmed one wipes and signs out (the snackbar, then
  the card back to Sign in), and a cancel keeps everything.
- iPhone 17 Pro simulator, with the T5 session and 110 unsynced rows: the button, the blocked dialog with the right count, and nothing
  deleted.

## Alternatives rejected

**A confirmation that names the count but lets the user through.** Before push it destroys the only copy, and one tap is too cheap for
that. It is the right shape once push exists.

**Keeping the data, encrypted, across a sign-out** (blueprint §33 option 2). It needs a key strategy per user, and the device-owner model
already covers "the same user signs back in".

**Deleting the database file.** That would lose `settings`, needs the database closed under live streams, and is not one transaction.

**Signing out first, then wiping.** A failed wipe would leave a signed-out device holding the previous user's data, owned by them, with no
session to fix it from.
