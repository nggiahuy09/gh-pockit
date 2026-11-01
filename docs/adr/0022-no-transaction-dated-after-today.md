# ADR 0022 — A transaction is never dated after today

## Status

Accepted — 2026-11-01 (W8 T4). Narrows ADR-0009 §6: `occurred_at` stays an
instant, but a local write cannot put it on a day after today.

## Context

Since W6 the form let a day up to a year ahead be picked, for a planned rent or
insurance payment. Nothing else decided what such a row means, and W8 T4 made
the gap visible:

- The balance query (ADR-0019) has no time filter, so an expense dated next
  month already lowered today's balance.
- The month card sums `[first of the month, first of the next)` (ADR-0021), so
  a rent dated the 30th counted as spent on the 1st.

The user closed it on 2026-11-01: a transaction records money that moved, and
planned money is not allowed.

## Decision

**A transaction's `occurred_at` falls on today or earlier, in the device's
calendar.** The rule is `occurredAt < tomorrow's local midnight`, built with the
`DateTime` constructor so a DST day is not assumed to be 24 hours.

- **The day, not the instant.** An edit keeps its time of day (W6), so an
  evening transaction moved to today may sit hours ahead of now. That is still
  today, which is what the picker offers.
- **Judged by the use cases, with `GPClock`.** `CreateTransactionUseCase` always
  checks. `UpdateTransactionUseCase` checks only when the edit changes the date,
  as ADR-0010 rule 3 does for the category. A row that is already ahead stays
  editable: another device's clock can run fast, or its zone can be ahead. The
  stored row is read only when there is something to judge, so an
  uncategorised edit dated today or earlier still makes one write and no read.
- **The refusal is `GPValidationCode.transactionDateInFuture`**, shown on the
  date field (ADR-0016). Picking another day clears it.
- **The picker stops at today.** It is widened to the day shown when an edit
  opens a row that is already ahead, so the field can still display it.
- **Nothing else enforces it.** The schema cannot: a `CHECK` has no "now". The
  entity cannot: it validates its own fields only (ADR-0010). A pull (P4) and
  a restore (ADR-0017) write what was there before, not a new choice.
- **No query changes.** The balance and the month card keep no `occurred_at <=
  now` term. A row ahead that arrives by sync counts like any other.

## Alternatives rejected

**The instant (`occurredAt <= now`).** An edit moved to today would be refused
whenever its kept time of day is later than now, so the form would have to clamp
it. A second of clock skew between two devices would refuse an otherwise valid
write.

**Keep dates ahead, and filter every aggregate on `occurred_at <= now`.** Every
total would then depend on the current second. Home's streams are fixed at build
(ADR-0021 amendment), so those totals would go stale without anything
re-running them. Planned money belongs to the recurring feature in the
blueprint, which can schedule it without pretending it has already moved.

**Judge the date on every update.** A row a fast-clock device dated tomorrow
could not have its note fixed until tomorrow came.

## Consequences

Positive:

- The balance and the month card hold only money that has moved, with no
  extra term in either query.
- Rows written before this decision, and rows that sync in ahead, need no
  migration. They stay editable, and moving them is judged.

Negative:

- No planned expenses until the recurring feature lands.
- The rule trusts the device's clock and zone. A user who sets the clock
  forward can date ahead, as with any client timestamp (§7).
- The picker's "today" is read when the form is built. A form left open past
  midnight still stops at the day before until it is rebuilt. That is stricter,
  never looser, and a save with no day picked still dates itself when saved.
