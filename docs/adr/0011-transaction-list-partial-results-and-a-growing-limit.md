# ADR 0011 — Reading transactions: partial results and a growing limit

## Status

Accepted — 2026-09-27, before W4. Settles the item ADR-0006 left for W4 T6 —
"that policy must be decided again at W4 T6, from scratch". Implemented from
W4 T4 (`TransactionQuery`, `TransactionRepository`) to W4 T6, and consumed by
the BLoC of W5.

## Context

Two questions about the one read every screen of this feature depends on.

**What a row the mapper refuses does to the list.** `accounts` and `categories`
fail the whole list (ADR-0006): with a handful of rows, an account silently
missing from a balance is worse than an honest error state. At transaction scale
the same rule lets one bad row — hand-edited while debugging, or written by a
newer build — hide a year of history behind an error screen with no way out.
Skipping the row silently is not better. A balance is a SQL `SUM` (ADR-0009)
that never goes through the mapper, so the list and the balance would disagree
with nothing on screen to say why.

**How the list pages.** The ROADMAP had `limit/offset`, and the list is a live
Drift stream. Offset paging over a live list breaks one of two ways. Pages
accumulated as snapshots shift under an insert at the top (a row repeats) or a
delete (a row vanishes). One live stream per page instead re-runs N queries on
every write, because drift invalidates per table. Blueprint §39 prefers keyset
paging, which is right for a static list and awkward for a live one: page one,
bounded by `LIMIT`, drops its last row when a new one arrives, and page two,
keyed strictly below that row, never shows it.

## Decision

**A refused row does not fail the list; the list says how many it could not
read.** `watchTransactions` emits a snapshot — the transactions it mapped, how
many rows the query returned, and how many of those the mapper refused — rather
than a bare `List`. The UI shows what it has and, when the refused count is not
zero, a notice that does not block it. Each refused row is logged with its id
and the mapper's reason and nothing else (golden rule 9) — once per stream, not
once per emission (settled at W4 T6): the list re-runs after every write, and one
bad row would otherwise repeat the same line for every edit the user makes. The type is
`TransactionListSnapshot` (settled at W4 T4): the mapped rows, `unreadableCount`
and `hasMore`, with `rowCount` derived from the first two rather than stored.

A query that fails — the database refusing, not a row — still puts
`GPDatabaseFailure` on the error channel, exactly as `accounts` does.

**Paging is one stream with a growing limit.** `TransactionQuery` has a `limit`
and no offset, and "load more" re-subscribes with a larger one. There is always
exactly one live query, what it returns is always a consistent prefix, and an
insert anywhere simply appears in the next emission. "There is more" is
`rowCount == limit` — rows, not mapped transactions, or a single refused row
makes the list believe it has reached the end.

_Settled at W5 T2,_ in `TransactionListBloc`: a page is 50 rows — judgement
until W8 times the list's first frame. "Load more" asks for the rows on screen
plus a page, counted in rows like `hasMore`, rather than for the current limit
plus a page. Asked twice for the same snapshot, that is the same window twice, so
the second ask is dropped: a scroll listener firing every frame costs one query,
the window never shrinks, and a larger window whose watch failed is not grown
past. Rows stay on screen while the larger window loads, being its prefix. A new
filter starts again at one page with nothing on screen; re-sending the filter
already in force changes nothing.

**The order is total: `occurred_at DESC, id DESC`.** Many rows share an
`occurred_at` — anything entered with a date and no time — and without the
tie-breaker SQLite may return them in a different order on each emission, so
rows jump. `id` is a v7, so ties fall back to creation order (ADR-0002).

**The filters, all ANDed:**

- account ids match **either side** of a transfer
  (`account_id IN (…) OR destination_account_id IN (…)`), or an account's history
  is missing every transfer into it;
- a date range is two instants, half-open `[from, to)`, computed by presentation
  from local dates (ADR-0009), so consecutive months never share a row;
- category ids and a set of types narrow further — a set, so "everything but
  transfers" can be said.

_Settled at W4 T4,_ in `TransactionQuery`: an empty set means no filter, the
same as `null` — "nothing selected" in a filter bar means everything, and a set
that matched no row would be the filter bug nobody reports, because the list is
merely empty. `limit` has no default: how many rows a screen shows is the
screen's decision (W5). There is no "uncategorised only" filter yet: a
transaction under a deleted category reads as uncategorised too (ADR-0010), so
that filter needs a join, and it is W26's.

## Alternatives

**Fail the whole list** (inherit ADR-0006). Proportionate at five rows, not at
fifty thousand.

**Skip the row, log it, say nothing.** The list silently stops adding up to the
balance.

**Wrap every emission in `GPResult`.** Rejected in ADR-0006 for what it costs the
common path, and it still cannot say "most of it worked".

**Offset paging.** See the context.

**Keyset paging now** (blueprint §39). Right for large static pages; on a live
list it needs one bounded range query per page to stay consistent. Deferred to
W26, where a benchmark can say whether the growing limit costs enough to
justify it.

## Consequences

Positive:

- One bad row costs the user a notice, not their history.
- The list and the balance can only disagree visibly.
- No row repeats or vanishes while the list is live, and W5's
  `LoadMoreRequested` changes a single number.

Negative:

- `TransactionRepository.watchTransactions` returns a type blueprint §22 does
  not have.
- Every emission re-maps up to `limit` rows, and deep scrolling re-runs an ever
  larger query. Cheap with the index of ADR-0009 and measured at W8; if the
  numbers say otherwise, W26 swaps the inside for keyset without changing what
  the BLoC sends.
- The notice needs copy in both languages and a UI state at W5.
- A refused row still has no repair path — the debt ADR-0006 names stays open.
