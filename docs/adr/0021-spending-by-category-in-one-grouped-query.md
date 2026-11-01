# ADR 0021 — Spending by category is one grouped query over a caller-given range, one row per category and currency

## Status

Accepted — 2026-11-01 (W8 T3).

Amended 2026-11-01 (W8 T4): one currency per query, named by the caller, and VND only for now. See the amendment at the end; the "one row per
category and currency" below is superseded.

## Context

W8 T3 is the first aggregate the app reads: what was spent, per category, in a
month. W8 T4 wraps it as `watchCategoryBreakdown()` next to the month's income
and expense totals on Home, W24's budgets compare against it, and W25's
analytics chart it. Blueprint §38 and the roadmap rule out loading the rows and
folding them in Dart: the sum is SQL.

Four things were open:

1. Where the month boundaries come from.
2. What a soft-deleted category's spending becomes. ADR-0010 says it reads as
   "Uncategorised" in analytics.
3. What happens when one category has expenses in two currencies. Accounts can
   be in USD next to VND (the debug sample data has one), and a transaction
   carries its account's currency (ADR-0010 rule 2).
4. Whether the query returns category ids, or the categories themselves.

## Decision

**One statement, `TransactionDao.spendingByCategorySql`, watched by
`TransactionDao.watchSpendingByCategory(ownerId, fromMillis:, toMillis:)`.**

```sql
SELECT c.*, t.currency_code AS spent_currency_code, SUM(t.amount_minor) AS spent_minor
FROM transactions t
LEFT JOIN categories c ON c.id = t.category_id AND c.deleted_at IS NULL
WHERE t.owner_id = ?1 AND t.type = 'expense' AND t.deleted_at IS NULL AND t.occurred_at >= ?2 AND t.occurred_at < ?3
GROUP BY c.id, t.currency_code
ORDER BY t.currency_code, spent_minor DESC, c.id
```

- **The range is the caller's, half-open `[from, to)`.** It is a pair of
  instants computed from a local calendar month above the data layer, the same
  as the list's date filter (ADR-0009 §6, ADR-0011). The SQL never computes a
  month itself.
- **Expenses only.** Income is not spending, and a transfer moves money without
  spending it (ADR-0009). A row of an unknown type adds nothing, as in the
  balance (ADR-0019).
- **A deleted category folds into the uncategorised group in SQL.** The
  live-category test sits in the join's `ON`, not in the `WHERE`. So the
  transaction is never dropped: its category joins as NULL, and it is grouped
  with the transactions that have no category. Any number of deleted categories
  give one uncategorised row, not one each.
- **One row per category and currency.** Minor units of two currencies do not
  add, and a SQL `SUM` never goes through `Money`'s currency check. Which
  currency a screen shows, and how, is W8 T4's call. This query only refuses to
  answer the question wrongly.
- **It returns the category row (`c.*`), not just its id.** The breakdown and
  its names and colours come from one snapshot, and the stream reads from both
  tables, so renaming or deleting a category re-runs it. This is the
  ADR-0019 shape again: `TransactionDao` already reads `accounts`, and now reads
  `categories` too. That is the direction `transactions.category_id` already
  points.
- **Order:** by currency, then largest spending first, then category id, so
  ties are stable. The uncategorised group's id is NULL, so it sorts first among
  equal amounts.

**No new index.** The plan is the one the W8 T2 audit predicted: a seek into
`transactions_owner_id_occurred_at_id` on `owner_id` and the range, one
primary-key lookup per row into `categories`, then a temporary B-tree for the
`GROUP BY` and another for the `ORDER BY`. Both B-trees hold one entry per
group, which is a handful. A DAO test pins the two seeks and forbids any `SCAN`.
The covering index the audit tried waits for W9's 50k numbers.

## Alternatives rejected

**Load the month's rows and fold them in Dart.** Rejected by blueprint §38 and
by the task itself. It also ships every row across the isolate boundary to
produce a handful of numbers.

**`GROUP BY t.category_id`, with deleted categories resolved in Dart.** Each
deleted category would arrive as its own row, all of them "Uncategorised", and
merging them is a fold in Dart.

**Month buckets in SQL with `strftime(..., 'localtime')`.** `'localtime'`
follows the time zone of the process SQLite runs in. That zone is not the
domain's to choose, a fake clock cannot fix it in a test, and a DST month
boundary becomes SQLite's problem. When W25 needs a six-month series, it can
pass the month boundaries in as values. It does not need to compute them in SQL.

**Filter to one currency.** There is no home-currency setting to filter by
yet, and choosing one here would decide W8 T4's question from the data layer.

**Ids only, merged with the categories stream in a use case.** Rejected for the
reason ADR-0019 rejected it for balances. The two streams can be one emission
apart, and the repo has no `combineLatest`.

## Consequences

Positive:

- The number is computed where the data is, through an index, and re-runs on a
  write to either table. A category deleted mid-month moves its spending to
  "Uncategorised" in the next frame, with nothing rewritten.
- Mixed currencies cannot be summed by accident.
- W24's budgets and W25's analytics get the same grouping and the same
  deleted-category rule, instead of re-deciding them.

Negative:

- Every caller handles more than one currency per category, even though almost
  every user has only one.
- The uncategorised row cannot say whether its money had no category or a
  deleted one. ADR-0010 says both read the same, so nothing needs to.
- Each matching row costs a lookup into `categories`. That is cheap by primary
  key, but it is the part a covering index would not remove. W9 measures it.
- A month is two instants computed in the device's current zone, so moving
  zones re-buckets the edges of a month, as ADR-0009 already accepts for days.

## Amended 2026-11-01 (W8 T4) — one currency, the month fixed per Home

W8 T4 puts the month on Home: a card with the month's income, spending and the
difference, and the breakdown under it. The user settled three questions on
2026-11-01.

**1. VND only, for now.** Both queries take the currency as a parameter (`?2`)
instead of grouping by it:

- `spendingByCategorySql` drops `t.currency_code` from its select, its
  `GROUP BY` and its `ORDER BY`, and filters on it instead.
- The new `incomeExpenseTotalsSql` sums income and expenses in one row with
  `SUM(CASE …)`. It filters the same way, returns zeros for an empty range,
  and counts a transfer as neither (ADR-0009).

The data layer still chooses nothing. `WatchMonthlySummaryUseCase.currency`
does, and `WatchCategoryBreakdownUseCase` reads it from there, so the
breakdown always adds up to the card's spending figure. A transaction in
another currency is left out of both, not converted: a user with a USD account
sees only the dong side of the month. Multi-currency revisits this, and it
needs no schema change to do so.

**2. Option A on Home** (canvas page "W8 · Trang chủ"). Home shows:

- the three largest categories;
- then "Uncategorised", always last whatever its size;
- then one line that sums the rest.

The bars are scaled to the largest group, with the share of the month's
spending beside each bar. The shaping belongs to presentation
(`HomeCategoryRows`). It folds a handful of groups that the query has already
summed, never transactions.

**3. The month is fixed when Home is built.** `HomePage` computes
`GPCalendarMonth.of(clock.nowUtc().toLocal())` once and hands it to both
blocs. An app left open across midnight on the first keeps showing the old
month until Home is rebuilt, which in practice means an app restart. If that
ever needs fixing, the fix belongs to the `appResumed` sync trigger (W21), not
a timer here.

`GPCalendarMonth` (core) turns a month into its two local midnights, the
instants the queries take (ADR-0009 §6). The totals query has the same plan as
the breakdown: a seek into `transactions_owner_id_occurred_at_id` on the owner
and the range. A DAO test pins it. No index is added.
