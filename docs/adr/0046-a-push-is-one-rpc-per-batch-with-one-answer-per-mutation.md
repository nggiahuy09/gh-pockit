# ADR 0046 — A push is one RPC per batch, with one answer per mutation

## Status

Accepted — 2026-11-28 (W14 T2, started early). This fixes the client half of the push contract. T3 writes the Postgres function that
answers it and amends this ADR with the server's rules (owner lock, `not_found`, how a rejection is caught per mutation).

## Context

ADR-0037 §3 already chose the transport: push and pull are Postgres functions called over RPC, `SECURITY INVOKER`, so RLS (ADR-0034)
and the stamping triggers (ADR-0036) still apply. It left their shape to W14. System-design §6.2 sketches a batch with a per-mutation
result; the ROADMAP task names `push(mutation)`, one at a time. Three things the client has to settle before T3 can write the function:
how many mutations a request carries, what each answer looks like, and what the data source does when the answer is not one.

## Decision

1. **One request carries a batch.** `GPSyncRemoteDataSource.push(List<GPSyncMutation>)` calls `push_mutations(mutations jsonb)` once.
   - ADR-0036 already expects it: the push takes the owner's lock at the start of a batch, so one lock for N rows, not N round trips.
   - The batch keeps the order the queue handed out (parents first, ADR-0044 §7). A child and its parent in one batch reach the server in
     one transaction, in order.
   - An empty batch sends nothing.
2. **The request is the queued row, nothing derived.** Each element is `mutation_id`, `entity_type`, `entity_id`, `operation`,
   `idempotency_key` and `payload`, the payload exactly as queued (ADR-0045, rejected alternative: a retry resends the bytes its key was
   first sent with).
   - No `base_version`: the base is the payload's `version` (ADR-0044, _Amended — T3_). A second copy could only disagree with it.
   - No owner beside the payload's `owner_id`: the server takes the owner from the token (ADR-0034, ROADMAP W11 T4).
   - Only a `processing` mutation is encoded, so only what `markSending` returned leaves, counted as an attempt (ADR-0044 §6).
   - Keys are snake_case, like the payload's server column names, so the function reads `m->>'entity_type'` without a mapping table.
3. **Each mutation gets exactly one answer:** `{mutation_id, status, …}` with three statuses.
   - `applied`, with `server_version` and `server_updated_at` (epoch milliseconds, §6), since the server's stamps replace the client's
     (ADR-0036).
   - `conflict`, with `remote`, the server's row, flat like a payload. System-design §7 needs both sides to show a conflict.
   - `rejected`, with a `code`: a constraint name (`transactions_destination_iff_transfer`, ROADMAP W11 T3) or `not_found`, never a value.
4. **An answer the client does not understand is refused whole.** An unknown status, a missing or extra field, an ISO time, an answer
   for a mutation not sent, a second answer for one, or a mutation left unanswered all throw `GPMalformedPushResponse`, which names
   the check only (golden rule 9). The engine then treats the batch as unanswered: nothing is completed on a guess (golden rule 6), and
   the idempotency key covers the retry.
5. **The data source neither retries nor classifies.** Transport errors (`PostgrestException`, a socket error) reach the caller as
   thrown; T5 maps them to `GPFailure` and the engine applies the retry policy (system-design §6.5).
   - The RPC turns off postgrest's own retry. Today it retries only `GET`, so this changes nothing yet, but the push must not depend on
     that default.
   - It sets a per-attempt timeout, 30 s by default. Postgrest has none, and a stalled socket would hold the sync lock until the OS gave
     up. The timeout aborts the request and throws `TimeoutException`.
6. **Where it lives.** The interface, the results and the wire codec are in `core/sync/` (`GP` prefix, §3); so is the Supabase
   implementation, beside `GPDriftSyncQueueRepository`. It is the sync's data layer, which ADR-0037 §4 means by `data/`. It takes
   `SupabaseClient.rest`, whose HTTP client adds the signed-in user's token. DI registers it only for a remote config; a local-only
   build has nothing to push to.

## Consequences

- T3's function has a fixed target. It returns a JSON array, one object per input element, and must catch a constraint error per
  mutation (a savepoint), or one bad row turns the whole batch into a transport error.
- A batch is all-or-nothing on the wire: a timeout leaves every mutation in it unanswered. That is the case idempotency keys exist for
  (W18), so batch size trades round trips against what one lost answer resends; the engine (T4) picks it.
- `deviceId` from §6.2 is not sent. Nothing on the server reads it yet; it joins the request with the first thing that does.

## Alternatives rejected

- **One RPC per mutation**, as the ROADMAP line reads. N round trips and N owner locks, and a parent and child no longer share a
  transaction.
- **Raw table upserts over PostgREST** instead of a function. ADR-0037 §3 rejected it: the version check and the per-mutation answer
  need logic on the server.
- **An Edge Function.** Nothing here needs more than SQL, and ADR-0037 keeps Edge Functions for what Postgres cannot do.
- **Completing the mutations a malformed response did answer.** Half-reading an answer this build does not understand is a guess.
