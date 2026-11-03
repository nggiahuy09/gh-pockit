# ADR 0025 — The benchmark dataset: 24 months of rows, written past the repositories in one batch

## Status

Accepted — 2026-11-02 (W9 T2).

## Context

W9 measures the app at 1k, 10k and 50k transactions (blueprint §55). Two choices decide what those numbers mean.

- **How the rows spread over time.** Blueprint §55 fixes 24 months. The Monthly Review proposal (F12) assumes a few hundred rows a month. At
  50k the two differ by a factor of seven in the rows a month holds, and the month aggregates on Home read one month.
- **How the rows get into the database.** The debug sample data goes through `SeedSampleDataUseCase` → `createTransaction`: one transaction
  per row, each one waking every open watch. On the test host (in-memory SQLite, 02/11), 1k rows that way took 358 ms with no watch open, and
  816 ms with one balance watch open, which re-ran 1,000 times. Each re-run reads a table that keeps growing, so 50k rows cost far more than
  50 × that.

## Decision

**Always the 24 months up to today, so the density grows with the size.** At 50k a month holds about 2,100 rows, about 68 a day. The user chose
this on 02/11 over a fixed realistic density (about 10 a day, which would spread 50k over 14 years). The month aggregates are pushed to their
worst case. A real user's month is lighter, so for those queries the numbers are an upper bound.

**The shape** (`BenchmarkDatasetGenerator`) comes from one seeded `Random`, so the same seed on the same day gives the same rows:

- Five accounts (cash, a salary bank account, an e-wallet, a credit card, a USD bank account) and the 11 default categories. A user cannot
  create a category yet (proposal F11), so there are no custom ones.
- Nine events on fixed days of every month: salary on the 5th, rent, four bills, a wallet top-up, a cash withdrawal, a card payment.
- The rest spread over the days, a weekend day weighted 1.3 times a weekday. Each row is one of 17 kinds (coffee, lunch, a ride, groceries,
  a daily transfer, a USD subscription, side income, …), each with its own hours, amount range, accounts and notes. VND amounts are whole
  thousands.
- About 5% of expenses uncategorised, 2% of rows tombstones, 40% with a note.
- Nothing dated after today (ADR-0022). `created_at` and `updated_at` are the seed time.
- Ids minted in `occurred_at` order, as a user's would be, so the id and rowid orders follow the date.

**`BenchmarkDatasetSeeder` writes it past the repositories, in one transaction.** The accounts go through `AccountDao.insertAccount`, the
transactions through one `TransactionDao.insertTransactions` batch, which stamps `pending` like every local write. It writes only for an owner
with no transaction, tombstones included, so a restart does not double the dataset.

**`--dart-define=DATASET=1k|10k|50k` triggers it on any non-release build.** The gate is `!kReleaseMode`, not `kDebugMode`, because benchmarks
run in profile. Bootstrap logs the size, the count and the elapsed milliseconds, which is the blueprint's "DB seed time". Since ADR-0026,
such a run opens a database file of its own, so the seed never lands beside real data.

**The seeder's ids come from its own `GPUuidGeneratorImpl` on a seeded `Random`,** not the app's singleton. `Random.secure` costs about
0.1 ms per id on the test host: 5.0 s of 50k ids, against 19 ms seeded. Two v7 generators can interleave ids minted in the same millisecond.
Nothing else mints a v7 while the seed runs, before the first frame, so that never happens here.

## Consequences

Positive:

- One commit, so an open watch re-runs once. 50k rows take about 0.9 s on the test host, generation included.
- The same seeder serves T3's query benchmark on the host and the device runs (cold start, first frame, scroll).
- Release builds never seed: the define is ignored there.

Negative:

- The rows skip the use-case rules: ADR-0010's category kind and ADR-0022's date. The generator meets them by construction, and a test pins
  each one. A rule added to a use case later is not checked here until a test says so.
- No row reaches the outbox (P4), so the dataset never syncs. That is the intent. The rows still read `sync_status = 'pending'` with no
  mutation behind them, so P4 must keep driving push from the outbox, never from that column.
- At 50k, balances go deeply negative: at 68 rows a day, spending outruns one salary. That is fine for timing, odd on screen, and a stress case
  for long amounts.
- The ids' random bits are predictable. No benchmark row needs them not to be.

## Alternatives rejected

**Through `createTransaction`, like the sample data.** Every rule is applied, but each row is its own commit and wakes every watch (see
_Context_). Once the outbox lands, each row would also queue a mutation, and the first sync would push the whole dataset.

**A fixed density of about 10 rows a day.** More like a real user, and month queries would stay at a few hundred rows whatever the size. The
user chose the blueprint's 24 months, which measures the month queries at their heaviest.

**Generate only in `test/`.** The device runs need the rows in the app's own database.
