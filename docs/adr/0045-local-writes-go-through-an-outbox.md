# ADR 0045 — Local writes go through an outbox

## Status

Accepted — 2026-11-27 (W13 Flex). This gathers the five W13 decisions you locked on 2026-11-25 (ROADMAP, _Kế hoạch W13_), plus the
sync badge. ADR-0044 holds the tables, the queue's contract and how each part was built and tested. This one says what the outbox is
for and the rules around it.

## Context

The UI never waits for the network (golden rule 1), so every write lands locally first and reaches the server later. Something durable
has to remember which writes are still owed. If that record could be lost or split from its write, a crash in between would leave a row
that never syncs and that nothing can detect (blueprint App. D).

## Decision

**Every local write of a synced entity queues a mutation in `sync_mutations`, in the same transaction** (golden rule 3). The push
(W14) sends mutations and deletes one only after the server's answer (golden rule 6).

- **A. A `'local'` row queues nothing.** An unclaimed device has no account to push to. The claim queues every row it moves, as
  `create`, in its own transaction. A device claimed before the outbox gets the same rows queued once at launch.
- **B. "Unsynced" means "has a mutation".** Accounts and categories carry no sync column. The sign-out count reads the outbox
  (ADR-0042).
- **C. Seeded categories are pushed too:** a transaction in one needs it on the server. The server treats a seed's `create` as "insert
  if absent". A seed still exactly as seeded does not count as unsynced.
- **D. One unsent mutation per entity.** A later write folds into it: the newest payload, and a `create` stays a `create`. A mutation
  that has been sent is never changed; the next write queues a new one. An entity's mutations leave the queue in order.
- **E. The payload is the row as written,** in the server's column names, taken at enqueue. A retry resends exactly what its
  idempotency key was first sent with. Its `version` is the base the server checks.
- **F. A transaction row shows a badge while it waits for its push.** `TransactionEntity.syncStatus` has three values:
  - `localOnly` for a `'local'` row, whatever the column says, because nothing will push it until a claim;
  - `pending`;
  - `synced`.

  The value is read from the row and used for display only, never to decide what to push. Only `pending` shows the badge: a small
  upload icon in the row's second line, cut off with that line on a narrow row. A screen reader reads "Chưa đồng bộ" / "Not synced
  yet". No `(sync_status)` index: the list query already reads the column.

## Consequences

- **What stops a lost write.** A crash cannot leave a write without its mutation. The invariant is checked after every step of a
  random walk over all write paths, and a crash before the commit is tested on every path (ADR-0044, _Amended — T6_).
- **Signing in costs time.** It queues the whole database. Measured on the host at 50k rows: 4.9 s, mostly spent minting ids. A cheaper
  key is a W14 decision.
- **Every transaction shows the badge until W14 pushes.** That holds for a signed-in device; a local-only one shows none.
- **Accounts and categories have no badge.** They would need their status read from the outbox; that waits until a screen asks for it.

## Alternatives rejected

- **Building the payload at push time from the current row.** A retry would send new content under an old idempotency key, and the
  server would answer with the old result.
- **A `sync_status` column on every synced table.** Adding it to two tables that hold data needs a default (ADR-0009 refuses one) or a
  rebuild, and the outbox already says what is unsynced.
- **A badge on every pending row, `'local'` ones included.** It would sit on every row of every local-only user, forever.
