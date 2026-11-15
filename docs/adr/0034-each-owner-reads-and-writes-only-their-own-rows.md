# ADR 0034 — Each owner reads and writes only their own rows

## Status

Accepted — 2026-11-08 (W11 T4, started early). You chose to make ids unique per owner now, while the tables on dev are still empty. No
local schema change.

## Context

- T3 turned RLS on with no policy, so nobody but the service role could read or write (ADR-0033).
- Supabase grants every privilege on a new `public` table to `anon` and `authenticated`. That includes `DELETE`, and `TRUNCATE`, which RLS
  does not cover at all.
- PostgREST runs each request as `anon` or `authenticated`, with the JWT claims in `request.jwt.claims`. `auth.uid()` reads `sub`.
- Synced rows are never hard-deleted (ADR-0031), and an undo clears `deleted_at` on a tombstone (ADR-0017).
- T3's primary key was `(id)` across every user. RLS filters which rows a user sees, not what is unique. An insert that collides with
  another owner's id fails with `23505`, whatever the policies say. A seeded category's v5 id can be computed from its owner's uid
  (ADR-0002), so one user could take another's id first: that owner's next write fails, and the error tells the first user the id exists.

## Decision

1. **Three policies per table, all `to authenticated`.** `select`, `insert` and `update`, each on `owner_id = (select auth.uid())`. Update
   has both `using` and `with check`, so a row cannot be handed to another owner. The subselect makes `auth.uid()` run once per statement,
   not once per row.
2. **No delete for a client.** There is no `DELETE` policy and no `DELETE` grant, so a delete fails with "permission denied" instead of
   quietly deleting zero rows. Purging tombstones (P4) is a server job under the service role.
3. **Least grants.** `revoke all` from `anon` and `authenticated`, then `grant select, insert, update` to `authenticated`.
   - `anon` gets nothing. Signing in comes first (W12), and a signed-out app reads its local database, never the server.
   - `TRUNCATE`, `REFERENCES` and `TRIGGER` are gone.
   - Every later table in `public` has to repeat the revoke and grant, because Supabase's default privileges grant everything. The test
     checks every table in `public`, so a table that forgets fails it.
4. **The update policy puts no condition on `deleted_at`,** so an undo (ADR-0017) works on the server too.
5. **The primary key is `(owner_id, id)` on all three tables.**
   - It replaces `(id)`, and replaces T3's `unique (id, owner_id)` as the target of the owner-scoped foreign keys. The constraint names
     stay the same.
   - An id only has to be unique within one owner, since a device only ever reads its owner's rows. One user can no longer block another's
     write, or learn that an id exists.
   - The leading `owner_id` also serves the policies' filter.
6. **A token with no `sub`** makes `auth.uid()` null, which matches no row.
7. **CI runs the suite.** A new job, `server schema (pgTAP)`, runs `supabase db start`, which replays every migration on a fresh Postgres,
   then `supabase test db`. It runs beside `quality`, and blocks a merge once it is added to the rulesets.

## Consequences

Positive:

- The test T4 asks for holds: A asking for B's row by id gets nothing. A also cannot write in B's name, update B's row, hand a row to B,
  hard-delete, truncate, or take B's id.
- A server schema regression fails on the PR, not on a device.

Negative:

- The server functions to come (W14 push, W15 pull) should be `SECURITY INVOKER`, so that these policies keep applying. A
  `SECURITY DEFINER` function bypasses RLS and has to check `auth.uid()` itself. That is W14's decision.
- The server's primary key differs from the local one. W14's upsert targets `(owner_id, id)`, with `owner_id` taken from `auth.uid()`
  rather than from the payload.
- Every new `public` table needs its own revoke and grant.
- A signed-out client cannot read anything from the server. There is no public reference data today.
- The CI job pulls a Postgres image on every run, about a minute.

## How it is tested

`supabase/tests/database/owner_access.test.sql`, 29 assertions:

- **Grants, policies, keys:** `anon` holds nothing on any `public` table; `authenticated` holds only `SELECT` / `INSERT` / `UPDATE`, on
  exactly the three tables; one select, insert and update policy per table, for `authenticated` only; each primary key is
  `(owner_id, id)`.
- **As A:**
  - Reads: their own accounts, categories and transactions, tombstone included, and nothing else. B's account, category and transaction
    asked for by id each return nothing.
  - Writes:
    - their own insert passes;
    - an insert in B's name fails with `42501`, also for a transaction on B's account;
    - updating their own account changes one row, and updating B's changes none;
    - handing their account to B fails with `42501`;
    - restoring their tombstone changes one row;
    - `DELETE` and `TRUNCATE` are refused;
    - inserting with B's category id gives A a row of their own, while a duplicate of A's own id still fails with `23505`.
- **No subject, anon:** a token with no `sub` reads nothing, and `anon` cannot even query.
- **As B, afterwards:** B's account is unchanged and A's are invisible. B's category id holds B's row only, and B can still write it.
- **What landed:** A's own update went through and the one on B's account did not. The refused delete left its row, and the restore
  cleared the tombstone.

`synced_tables.test.sql` drops its four "nobody until T4" assertions and keeps 31.

Checked that the tests bite: with the accounts select policy set to `using (true)`, no `revoke`, and `categories` still keyed on `(id)`,
13 assertions fail. Among them, A's `TRUNCATE` really emptied the table. With the migration restored, all 60 pass.

## Alternatives rejected

**One `for all` policy per table.** It would include `DELETE`.

**A delete policy limited to tombstones.** It is still a hard delete from a client, against ADR-0031, and no other device would hear of it.

**Keep `anon`'s `SELECT` and let RLS return `[]`.** It is harmless today but is a grant nothing uses, and revoking everything is simpler
than picking out `TRUNCATE` and the rest.

**Keep the primary key on `(id)` and write the risk down.** The attack needs the other user's uid, which the app never shows. But changing
the key later means a migration over a live table, against nothing now.
