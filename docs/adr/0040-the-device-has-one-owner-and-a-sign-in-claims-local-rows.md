# ADR 0040 — The device has one owner, and the first sign-in claims the `'local'` rows

## Status

Accepted — 2026-11-16 (W12, the "claim `'local'`" step, started early). You chose decisions A and B of the W12 plan on 2026-11-15, and on
2026-11-16 that the owner stays until an explicit sign-out. This carries out the step ADR-0001 named in W2 T3: claiming the rows is a
sign-in step, not a migration. No schema change: the owner is a row in the key/value `settings` table.

Amended 2026-11-27 (W13 T5, ADR-0044): the claim also queues a `create` for every row it moves, in the same transaction. A `'local'`
row queues nothing until then.

## Context

- Since W2 every synced row is written with `owner_id = 'local'` (ADR-0001). Each repository and seeder took that string as a constant in
  DI.
- Sign-in is optional (decision E). A user can track for weeks and register later, and must keep those weeks (the W8 debt note).
- Seeded categories take a v5 id over `owner_id|name_key` (ADR-0002 amendment), so two devices mint the same id for "Food". A seed made
  for `'local'` has ids no other device of the same user will ever mint.
- Every `watch…` query filters on the owner when it subscribes. If the owner changes under an open list, the list goes on filtering on
  the old one and goes empty.
- `transactions.category_id` references `categories(id)`, with no `ON UPDATE CASCADE`, and foreign keys are on.
- A session can end without the user signing out: the server refuses the refresh token (ADR-0039). Whose data is the device holding then?

## Decision

1. **The device has one owner, a `settings` row (`owner.id`):** `'local'` until a claim, then the user's uid.
   - Only an explicit sign-out (T6, which wipes) resets it.
   - A session that ends by itself leaves it as it is. The data stays visible, and still belongs to the user who signed in. Signing
     back in resumes.
2. **`GPOwnerContext` (`core/database`)** replaces the constant (decision A).
   - `current` is the owner for writes and one-shot reads.
   - `watch()` emits the current owner, then each change. Every repository `watch…` is built on it with `switchMap`, so an open list
     follows a claim instead of going empty.
   - `GPSettingsOwnerContext` caches the row. The bootstrap loads it after the database opens, before any read or seed.
   - The claim calls `adopt(uid)` right after its commit, synchronously, so no open query is re-run for `'local'` in between. That gap
     emitted an empty list, and the test caught it.
3. **The claim is one transaction** (`DeviceOwnerDao`): all of it or none.
   - `PRAGMA defer_foreign_keys = ON`. Unlike `foreign_keys`, it works inside a transaction, and it resets at the end.
   - **Seeded categories take the id they would have had if seeded for the user**, v5 over `uid|name_key`, and their transactions
     follow (decision B). Another device of the same user then has the same rows, and the seed after the claim inserts nothing.
     - If the user's own seed is already on the device, the `'local'` copy is deleted outright. It was never synced, so no other device
       needs a tombstone for it.
     - A category the user made keeps its v7 id.
   - Then `accounts`, `categories` and `transactions` move from `'local'` to the uid with `updated_at = now` and
     `version = version + 1`, and `owner.id` is written in the same transaction.
   - `sync_status` stays `pending`. There is no outbox yet; W13 T5 backfills a mutation for every pending row.
4. **When a claim runs** (`ClaimLocalDataUseCase`):
   - **after a sign-in or a sign-up.** The server has answered, so the uid is known;
   - **at launch, for a restored session** (`RestoreSessionUseCase`). A claim that did not land last time, after a crash or a database
     error, lands here.
5. **Against the device owner:**

   | Device owner      | Signing in as user U                                                                                   |
   | ----------------- | ------------------------------------------------------------------------------------------------------ |
   | `'local'`         | claim. Returns how many rows moved                                                                     |
   | U                 | nothing to do                                                                                          |
   | another account V | U is signed out again. `GPValidationFailure(authDeviceOwnedByAnotherAccount)` goes on the form banner |

   - **Wiping V's data is a sign-out's job, never a sign-in's.** The form says to sign out of that account first.
   - **A claim that fails in the database does not undo the sign-in.** The rows stay `'local'`, it is logged, and the next launch claims
     them.
6. **The seeders read the owner when they run.** `CategorySeeder.seededId` is the one place the id is derived, and the claim calls it
   too.

## Consequences

Positive:

- Days offline, then a sign-up: every row is still there and every row is the user's. There are no duplicate seeded categories, and a
  second claim changes nothing.
- An open screen keeps showing its rows through the claim.
- A dropped session never hides the data, and never hands it to whoever signs in next.

Negative:

- **One more step before the first frame:** the owner `settings` read, on every launch, local-only included.
- **The claim rewrites every row** (version + 1, updated_at), and on a large database that takes time. It is not measured yet at 50k
  (ADR-0026). It runs once per device, at the first sign-in.
- **Signing in as another account on a device that still holds V's data needs a sign-out first,** which arrives with T6. Until then, the
  refusal has no button that resolves it.
- **The domain names the sentinel.** `ClaimLocalDataUseCase` compares with `localOwnerId` from `core/database/owner_id.dart`, a plain
  constant with no drift import.
- **The auth feature's data layer imports the categories seeder** for `seededId`. That is a second cross-feature data import, after the
  benchmark seeder's.
- **The test fake `FixedOwnerContext` replaced `ownerId:`** in about 35 test constructors.

## How it is validated

- `device_owner_repository_impl_test.dart` covers the real repositories, seeder and settings owner on one in-memory database:
  - days offline then a claim: row counts kept, every row the user's, version up, `updated_at` now, still pending, the lists read them;
  - seeded ids re-derived and transactions following them, an own category keeping its id, `PRAGMA foreign_key_check` empty;
  - the seed after a claim inserting nothing, and a second claim changing nothing;
  - an open list following without ever emitting empty;
  - the user's own seed already present, so the `'local'` copy goes;
  - a trigger refusing the last table's move: everything rolled back, still `'local'`, `GPDatabaseFailure`, logged;
  - the owner read back after a relaunch.
- The use cases: an unclaimed device, the same user, another account (signed out, refused), a database failure that keeps the
  sign-in, and the claim at restore.
- `GPSettingsOwnerContext`, `switchMap` (the bloc transformer now uses the shared one), and DI.
- iPhone 17 Pro simulator, `--flavor dev` with `env/dev.json` and the sample data: the app opens on Home with every row read through the
  owner context. A real sign-in on the device waits for T5.

## Alternatives rejected

**The owner follows the session** (signed in means uid, otherwise `'local'`). A dropped session would hide the user's rows. Rows written
meanwhile would go to `'local'`, and the next sign-in would hand them to whoever it is, even another account.

**Re-registering the repositories on an auth change.** Every bloc already holding a repository would keep the old one. A singleton
context that a query follows is simpler to test.

**Keeping `'local'` seeded ids after the claim.** The user's second device seeds v5 over `uid|key`, so the categories would appear twice
after the first sync, and the seeder would add a second set on this device.

**Dropping the owner filter from local reads**, since the database holds one owner anyway. The indexes lead with `owner_id` (ADR-0009,
ADR-0027), and the filter is what keeps a stray row from the server out of the lists.
