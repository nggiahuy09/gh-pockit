# Benchmarks

How Pockit is measured at 1k, 10k and 50k transactions. The dataset is described in ADR-0025, and the harness in ADR-0026.

Results: [10k](10k.md) (W9 T4, iPhone 15), [50k](50k.md) (W9 T5–T6, before and after).

## Before / after — W9 T6

Two changes came out of the 50k run. Each one fixes the slowest thing its tier found.

| What | Where measured | Before | After | Change |
| ---- | -------------- | -----: | ----: | ------ |
| Account balances, 50k | host, repository median | 26.8 ms | **5.0 ms** | the two account indexes widened to cover the query, schema v5 ([ADR-0027](../adr/0027-account-indexes-cover-the-balance-query.md)) |
| … p90 | host | 35.5 ms | 5.4 ms | |
| Seeding 50k rows (write cost) | host | 985 ms | 991 ms | unchanged |
| List scroll, worst build frame, 50k | Android emulator, profile | 1,921 ms | **132 ms** | each day card became a lazy sliver ([ADR-0028](../adr/0028-day-card-is-a-lazy-sliver.md)) |
| … p99 build frame | emulator | 599 ms | 42 ms | |
| … frames over the build budget | emulator | 301 / 1,166 | 131 / 1,818 | |
| … build time of the frame after a new 1,000+-row window | emulator | 1–2.5 s, growing with the window | 17–58 ms, flat | |

Host numbers are JIT and emulator numbers are noisy, so each one is compared only with its own kind. The iPhone 15 numbers at 10k
([10k.md](10k.md)) are the "before" on real hardware. The "after" on the iPhone has not been run yet.

## The dataset

`BenchmarkDatasetGenerator` writes 1,000, 10,000 or 50,000 transactions over the 24 months up to today, from a fixed seed.

- 5 accounts, one of them in USD, and the 11 default categories.
- 9 fixed-day events a month: salary, rent, bills, transfers.
- The rest are spread over the days, weighted towards weekends, across 17 kinds of everyday spending.
- About 5% of expenses are uncategorised and 2% of rows are tombstones.
- At 50k, a month holds about 2,100 rows. For the month queries that is a worst case, not a typical user.

## Tier 1 — queries, on the host

```bash
fvm flutter test test/benchmark --dart-define=DATASET=10k
```

- It opens the app's connection, a file on a background isolate, and seeds it.
- It times ten cases: the list (newest 50, 500 and 2,000); the list filtered by the busiest account, the quietest account, an account with
  3 rows, and the busiest category; the month totals; the spending by category; and the balances.
- Each case is timed at two layers: the SQL statement, and the repository's first emission.
- The report goes to `build/benchmarks/queries-10k.md`, with each case's `EXPLAIN QUERY PLAN`.
- The Dart side runs in JIT here, so compare these numbers only with other host runs.

## Tier 2 — frames, on a phone in profile mode

Use a physical device. The iOS simulator cannot build in profile mode, and an emulator's numbers do not represent a phone.

```bash
fvm flutter drive --profile --keep-app-running --no-dds --driver=test_driver/integration_test.dart --target=integration_test/app_benchmark_test.dart --dart-define=DATASET=10k -d <device>
```

- **Never drop `--keep-app-running`.** Without it, `flutter drive` uninstalls the app when the test ends, and the real data goes with it.
- `--no-dds` lets the app open its own VM Service connection, which `watchPerformance` needs to read GC counts.
- It writes `build/integration_response_data.json`:
  - `home_data_ms`: from bootstrap to Home showing data;
  - `transactions_first_rows_ms`: from the tab tap to the first row;
  - `transactions_scroll`: build and raster time per frame over 30 flings, and the frames that missed their budget;
  - `slow_build_frames_after_a_snapshot` (with its `_detail`): the slow frames whose build began within 50 ms of a new list window, each
    with the window's size. This shows whether the spikes come from the list's rebuild;
  - `clock_lead_ms`: small and positive when the frame clock and `Timeline.now` agree. The matching above relies on that.
- The run uses its own database, `pockit_bench_<size>_v<version>`, and never touches the real data.
- The first run of a size seeds that database. Throw that run's numbers away, then take the median of three or more runs.

## Cold start

```bash
fvm flutter run --profile --trace-startup --dart-define=DATASET=10k -d <device>
```

- It writes `build/start_up_info.json`; `timeToFirstFrameMicros` is the number to keep.
- The app exits after the first frame. Run it once to seed, then measure the runs after that.
