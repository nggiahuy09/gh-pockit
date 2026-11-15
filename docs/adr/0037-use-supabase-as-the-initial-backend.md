# ADR 0037 — Use Supabase as the initial backend

## Status

Accepted — 2026-11-09 (W11 Flex). The blueprint reserved this as "0005", a number that went to design tokens. The decision has been in
effect since W11 T2; this records why, and the limits it sets. No schema change.

## Context

- The project's subject is the client: an offline-first data architecture, and a sync engine that holds when the network does not
  (CLAUDE.md §1). The backend has to give that sync engine a correct other end, not become a second project.
- P4's sync engine needs, on the server:
  - per-user authentication;
  - a relational store with real constraints and transactions;
  - authorisation per row;
  - a way to run push and pull as server-side logic (system-design §6.2).
- Blueprint §31 weighed two options. Option A is Supabase, recommended to get going. Option B is a custom NestJS backend, worth learning
  but a large increase in scope. Its recommendation: the client and Supabase first, and NestJS later, behind the same remote data source.

## Decision

1. **Supabase is the backend for P3 and P4.** It provides Auth, Postgres, row-level security, and the Data API (PostgREST, including
   RPC calls to Postgres functions).
   - **Projects:** one dev project, `pockit-dev`, in `ap-northeast-2` (Seoul), on Postgres 17.11. Its URL and publishable key live in
     the gitignored `env/dev.json` (ADR-0032). There is no prod project yet.
   - **Not used yet:** Realtime, Storage and Edge Functions. Storage arrives with receipts (blueprint §34: a private bucket and signed
     URLs). An Edge Function is used only for what a Postgres function cannot do.
2. **The server's rules live in Postgres:** constraints, RLS, and triggers.
   - They are versioned in `supabase/migrations/` and tested with pgTAP, plus one two-session race script. The tests run on a local
     stack in Docker and in CI (ADR-0033 to ADR-0036).
   - Migrations reach dev only through `supabase db push --remote`, run by hand. CI holds no Supabase credentials and deploys nothing.
3. **Sync runs through server functions, not raw table writes.** The push and pull of system-design §6.2 become Postgres functions,
   called over RPC. They are `SECURITY INVOKER`, so RLS and the stamping triggers still apply (ADR-0034, ADR-0036). W14 decides their
   exact shape, and whether anything needs an Edge Function. The JSON contract stays backend-neutral.
4. **Supabase stops at the data layer.**
   - `supabase_flutter` enters at W12, and only `data/` imports it (golden rule 8).
   - Auth sits behind `AuthRepository`, and sync behind `SyncRemoteDataSource`.
   - No Supabase type (`Session`, `User`, `PostgrestException`) reaches the domain. Each maps to the app's own entities and to
     `GPFailure`.
   - Replacing Supabase with the NestJS of Option B means a new data source plus a server. The domain, the BLoCs and the local database
     do not change.

## Consequences

Positive:

- Auth, a managed Postgres and row-level authorisation with no server to run. W11 T2 to T6 took two days of the week.
- Postgres gives the server the constraints, foreign keys and transactions the sync design relies on (ADR-0009, ADR-0033), plus
  authorisation that can be tested in SQL (ADR-0034).
- The remote layer can be swapped, which keeps blueprint §31's NestJS path open.

Negative:

- **Rules live in two languages.** Dart in the domain, and SQL and plpgsql on the server, for example ADR-0010's fixed currency, which
  both enforce. A rule that changes must change in both, in one PR.
- **Some coupling cannot be abstracted away.**
  - User ids come from `auth.users`, and every `owner_id` references it.
  - The policies use `auth.uid()`.
  - The functions follow PostgREST's conventions.

  Leaving Supabase means moving users with their ids, and rewriting the policies as checks in the new server. Postgres itself, and
  every constraint and trigger, would carry over.

- **Migrations are deployed by hand.** Dev can drift from the repo. It did on 2026-11-09, when T6 was applied before it was committed.
  Before a PR, `supabase migration list --remote` must show local and remote in step. Deploying from CI with a scoped token can come
  with the prod project.
- **Server work needs Docker,** for the local stack and for `supabase test db`.
- **The free plan pauses quiet projects.** On it, an inactive project is paused after about a week at the time of writing, and has to be
  resumed from the dashboard. The project would then look down to the app until it is. This needs checking before relying on dev for
  long-running tests.
- **The region is fixed when a project is created.** Dev is in Seoul. Prod's region is a choice to make deliberately, since this is
  financial data.

## How it is validated

What W11 built on it:

- the dev project, with email/password sign-in and email confirmation off (ADR-0032);
- four migrations: the tables, owner-only access, the delta-pull indexes, and the server stamps (ADR-0033 to ADR-0036);
- 88 pgTAP assertions and the two-session race test, green locally and on the dev project (the race test locally only, since it needs
  `docker exec`);
- through the Data API with the publishable key, `anon` is refused on all three tables.

The swap boundary in decision 4 is checked from W12 on, by the existing rule that presentation never imports `supabase_flutter`.

## Alternatives rejected

**A custom backend now: NestJS and Postgres (blueprint §31, Option B).** It gives full control of the API, idempotency and the sync
endpoints. But auth, hosting, migrations and operations all become the project's own work, ahead of the client work the project exists
for. It stays the planned second step, behind the same data source.

**Firebase (Firestore and Auth).** Its SDK ships offline persistence and its own sync, which would replace the engine this project
exists to build. As a document store, it cannot express the foreign keys, CHECKs and multi-row transactions that ADR-0009 and ADR-0033
rely on.

**A self-hosted backend in one binary, such as PocketBase.** It is simple to start, but running it, backing it up and securing it all
fall on the project. Its SQLite store is single-node.
