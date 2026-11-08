# ADR 0033 — The server schema mirrors the local one, with the checks a server can afford

## Status

Accepted — 2026-11-08 (W11 T3, started early). You chose: the Supabase CLI with a Docker-backed local stack and pgTAP tests,
`bigint` epoch-millisecond timestamps, and vocabulary CHECKs on the server. No local schema change.

## Context

From P4 on, each device pushes its rows to Postgres and pulls everyone else's changes back. The server tables are the far end of the
three-model rule: `TransactionDto` maps to them as `TransactionRow` maps to the local table. What they have to respect:

- **Local types:** SQLite `INTEGER` for money (ADR-0007), for timestamps (epoch milliseconds, CLAUDE.md §6) and for `version`. `TEXT` ids
  (v7, or a v5 for seeded categories, ADR-0002). A `TEXT` owner that is `'local'` until sign-in claims it (ADR-0001).
- **The pull cursor** is `(updated_at, id)` (W15), stored by the client.
- **Local constraints** (ADR-0009): positive amounts, the transfer shape, foreign keys with no `ON DELETE` checked immediately. No
  vocabulary CHECK, because SQLite needs a table rebuild to change one.
- **The server holds many owners; a device holds one.** A foreign key check runs as the table owner and ignores RLS. A seeded category's
  id can be computed from its owner's uid (ADR-0002).
- **Supabase serves `public` through the Data API** to anyone holding the publishable key, which is public by design (ADR-0032), from the
  moment a table exists.

## Decision

1. **Same tables, columns, names and nullability, minus `sync_status`**, which is the device's own sync state. Column by column: a `TEXT`
   id is a `uuid`; the owner is a `uuid` referencing `auth.users`; every `INTEGER` is a `bigint` (money, timestamps, `version`); a boolean
   is a `boolean`; text stays `text`. No column defaults, for the reason the local tables give: a value nobody wrote would pass for one
   somebody did.
2. **Timestamps are `bigint` epoch milliseconds.** The W15 cursor then compares exactly what the client stores, and the DTO maps an int to
   an int. `timestamptz` would bring microseconds: unless every server write truncated them, a cursor rounded to milliseconds would
   re-send the last row of a page forever. It would also bring ISO strings to parse. T6's trigger takes "now, in milliseconds" from one
   helper.
3. **The checks a server can afford:**
   - **Vocabulary CHECKs** on the three `type` columns. Postgres changes a CHECK with one `ALTER`, so ADR-0009's reason does not hold
     here. And the server is the one place every device's data passes through: a bad value one client writes would otherwise break the
     mapper of every device that pulls it. A new value ships to the server first, then to the client.
   - **`currency_code ~ '^[A-Z]{3}$'`**: `Money`'s own rule, stricter than the local `length = 3`.
   - **Named table-level constraints** (`transactions_destination_iff_transfer`, `transactions_destination_not_source`,
     `transactions_transfer_without_category`, `categories_name_or_name_key`). A violation names its rule, which the tests match on and
     W14's error mapping can.
4. **Owner-scoped foreign keys.** A child references its parent's `(id, owner_id)`, and each parent carries `unique (id, owner_id)`. A
   plain `references accounts (id)` would accept a transaction on another user's account or category. The constraint holds for every
   role, the service role included, which an RLS `with check` subquery would not.
5. **`owner_id` references `auth.users` with `on delete cascade`.** Deleting a user deletes their rows in that one statement. The children's
   foreign keys to their parents are `NO ACTION`, which is checked at the end of the statement, after the cascade has removed them.
   Nothing else is ever hard-deleted (ADR-0031).
6. **RLS is on in the migration that creates the tables, with no policy yet.** The anon and authenticated roles read and write nothing
   until T4 adds the owner policies. The tables can land on dev before their policies without a row ever being exposed.
7. **No index beyond the primary keys and the uniques.** The first server query, the delta pull, gets its index in T5: ADR-0009's rule,
   applied to the server too.
8. **Tooling:**
   - `supabase/` lives at the repo root.
   - Migrations go in `supabase/migrations/`, named by `supabase migration new`. A migration that has been pushed is never edited; the
     next change is a new file. This is the same rule as a shipped local schema version.
   - Tests are pgTAP files in `supabase/tests/database/`, run by `supabase test db` against the local stack (Docker, through OrbStack).
     `supabase db reset` replays every migration from scratch.
   - `supabase db push --remote` applies the migrations to the linked dev project. Without `--remote`, CLI 3.x targets the local stack.
   - The local `config.toml` mirrors the dev project's auth settings: sign-up on, email confirmations off.

## Consequences

Positive:

- A malformed or cross-owner row is refused at the server.
- Mapping stays trivial: the names match, and ints stay ints.
- The schema can reach dev before T4 without opening anything.

Negative:

- A new value in a `type` column means a server migration before the client ships.
- Server SQL needs Docker running. The local stack's first start pulls images on the order of a gigabyte.
- Drift between the server and local schemas is caught only by a hand-written shape test (`results_eq` over `information_schema`), not by
  generated code as on the device. From P4 on, a change to a synced local table changes the server in the same PR.
- Millisecond integers are not readable in Studio. SQL that needs a date converts with `to_timestamp(updated_at / 1000.0)`.
- Each parent table maintains one more unique index on every write.

## How it is tested

`supabase/tests/database/synced_tables.test.sql`, 35 assertions:

- **Shape:** every column, type and nullability of each table, in order; no column defaults; RLS on for all three tables.
- **Accepted:** what the local schema accepts. That includes an amount of 10^15 (past 32 bits), an expense in a soft-deleted category
  (ADR-0010), two user-made categories with `NULL` name keys, and the same `name_key` seeded by a second owner.
- **Refused:**
  - the `'local'` owner and an owner who is not a user;
  - each vocabulary, a lowercase or two-letter currency, a zero or negative amount;
  - the three transfer rules, and a category with neither name nor name key;
  - a seeded `name_key` repeated for one owner;
  - four cross-owner references.
- **Access:** an authenticated owner reads none of their own rows and cannot insert one; anon reads nothing.
- **Deletion:** deleting a user removes their accounts, categories and transactions, and leaves the other user's rows.

Checked that the test bites: with a plain foreign key on `account_id` and RLS off on `accounts`, five assertions fail. With the migration
restored, all 35 pass.

## Alternatives rejected

**`timestamptz`.** Idiomatic and readable in Studio. Rejected for the cursor precision trap and the parsing in decision 2.

**Mirror local exactly, with no vocabulary CHECKs.** A bad value would then be caught only by the mapper of the device that pulls it,
which can then no longer finish its pull.

**Plain foreign keys, with ownership checked in RLS policies.** It needs a subquery per write in a `with check` policy, and the service
role bypasses it.

**Postgres `enum` types for the vocabularies.** A value can be added but never removed, and `text` with a CHECK keeps the column as the
local table has it.

**The dashboard SQL editor, or the CLI without Docker.** No repeatable tests, and nothing records which migration has run.
