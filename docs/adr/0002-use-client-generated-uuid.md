# ADR 0002 — Use client-generated UUIDs, v7 for entity keys and v4 for idempotency keys

## Status

Accepted — 2026-09-09 (W1 T5)

> Numbered 0002 to match the slot Appendix E of `docs/blueprint.md` reserves for
> this decision. ADR 0001 (_Use Drift as local source of truth_) was drafted in
> W1 flex and is accepted in W2, once an `AppDatabase` exists to accept it.

## Context

The app is offline-first: a transaction created on a plane has to be written,
referenced and displayed long before any server hears about it. That rules out
server-assigned identity — golden rule 4 in `CLAUDE.md`. An ID that arrives
later cannot be a foreign key now, so an outbox mutation, a receipt row or a
transfer's sibling leg would have nothing to point at.

Client-generated identity then raises two questions this ADR answers:

1. Which UUID variant does an entity primary key use?
2. What generates them, given that sync tests must be deterministic?

The second question is the reason `GPClock`, `GPUuidGenerator` and `GPAppLogger` are
interfaces registered in `get_it` rather than static calls. A sync test that
asserts "the same mutation retried twice keeps one idempotency key", or "after
two failures the next attempt is 4s away", cannot be written against
`DateTime.now()` and `Uuid().v4()` without a real `Future.delayed` — which
`CLAUDE.md` §8 forbids for exactly this reason.

## Decision

- IDs are generated on the client, always, for every synced entity.
- **Entity primary keys use UUID v7.** Its leading 48-bit millisecond
  timestamp makes new keys sort after old ones, which keeps SQLite index
  inserts append-only and gives `ORDER BY occurred_at DESC, id DESC` a
  tiebreaker that matches creation order.
- **Idempotency keys use UUID v4.** They are only ever compared for equality;
  ordering is meaningless and embedding creation time in them leaks
  information for no gain.
- `package:uuid` is wrapped by `GPUuidGenerator` in `lib/core/utils/`. That
  interface is the app's only entry point; the package is imported in exactly
  one file.
- **`v7()` fills `rand_a` with a monotonic 12-bit counter** (RFC 9562 §6.2
  "method 2") instead of random bits, and the counter is seeded from the
  injected `GPClock`:
  - same millisecond → counter increments;
  - counter past 4095 → borrow the next millisecond, reset the counter;
  - wall clock jumps backwards (NTP) → keep the previous timestamp and
    increment, so an ID handed out later never sorts earlier.
- `GPUuidGenerator` is registered as a **lazy singleton**. The counter is
  per-instance state, so two instances would interleave out of order.

## Alternatives

**Server-assigned integer IDs.** Smallest keys, natural ordering, and the
option is dead on arrival: it needs a round trip before a row can exist.

**Auto-increment local rowid plus a server ID column.** Two identities per row,
and every foreign key has to pick one. Every sync path then needs a
translation step, and the local ID leaks into the UI as a stable-looking
handle that changes meaning after the first sync.

**UUID v4 for everything.** One code path, no timestamp anywhere. Rejected for
keys: random keys scatter B-tree inserts across the whole index, which is what
turns the 50k-row benchmark in P2 into a problem, and they give no ordering to
fall back on when two rows share an `occurred_at`.

**Plain `package:uuid` v7, no counter.** What the package ships: all 74 free
bits random. RFC 9562 compliant, and it orders IDs only _between_
milliseconds — two IDs created in the same tick sort at random. That is not a
corner case here: a bulk insert, a sync pull applying a page, and the seed of
default categories all create many rows inside one millisecond. Rejected once
a test showed 500 IDs generated in a loop come out unsorted.

**Hand-rolled v7, no package at all.** Considered; the package still earns its
place for v4, for the byte layout and for the version/variant masking. The
counter is the only part worth owning, and it is ~20 lines.

## Consequences

Positive:

- A row is complete the moment it is created, offline included. Foreign keys,
  the outbox mutation and the UI all work with no server round trip.
- Keys sort in creation order, tie-break deterministically, and keep index
  inserts sequential.
- Time and identity are injectable, so sync tests run on a `FakeClock` with no
  `Future.delayed` and no flakiness.
- Idempotency keys carry no timestamp.

Negative:

- 36-char text keys instead of 8-byte integers: larger index and larger rows.
  Accepted; measured again in the P2 benchmark.
- The monotonic counter is our code, not the package's, so it is on us to keep
  it correct. Covered by tests for the same-millisecond, cross-millisecond,
  clock-rewind and counter-overflow cases.
- `GPUuidGenerator` must stay a singleton. A future `registerFactory` would
  silently break ordering, which is why the DI test asserts singleton
  identity.
- A v7 key exposes roughly when a row was created to anyone who can read the
  key. Acceptable for a per-user finance app; it is why idempotency keys, which
  travel to the server, are v4.
