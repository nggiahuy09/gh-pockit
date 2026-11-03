# ADR 0026 — The benchmark harness: a query tier on the host and a device tier through `integration_test`

## Status

Accepted — 2026-11-02 (W9 T3).

## Context

W9 T3 asks for four numbers: cold start, the transaction list's first frame, scroll jank and the dashboard queries. Several earlier
decisions also wait on W9's measurements:

- the covering indexes (ADR-0019, ADR-0021);
- `UNION ALL` for the account filter (W4 T5);
- the partial index (ADR-0009);
- `pageSize` and the window that grows as the list scrolls (ADR-0011);
- the row copy and mapping on the UI isolate (W8 T6);
- the three joined parents of a list row (ADR-0024).

Two constraints shape the harness:

- `flutter test` runs on the host in JIT and draws no real frames. It can time a query. It cannot measure a frame.
- The reference phone (an iPhone 15) holds real data. The seeder writes only into an owner with no transaction (ADR-0025), so it would never
  seed there.

## Decision

**Tier 1: the queries, on the host.** This is `test/benchmark/query_benchmark_test.dart`, run with
`fvm flutter test test/benchmark --dart-define=DATASET=10k`.

- It opens the app's own connection (`openAppConnection`), a file on a background isolate. Every result therefore pays the copy across
  isolates, as it does on a phone.
- It seeds with the T2 seeder.
- It measures eight cases:
  - the list at 50, 500 and 2,000 rows;
  - the list filtered by the busiest account;
  - the list filtered by the busiest category;
  - the month totals and the month's spending by category, for the last whole month;
  - the account balances.
- Each case is measured at two layers:
  - the statement the DAO watches, read once with `get()`;
  - the first emission of the repository's watch, which is what a bloc receives.
- Each case gets 5 warm-up runs and then 30 measured ones, reported as median, p90 and max.
- The report includes each case's `EXPLAIN QUERY PLAN`, and goes to `build/benchmarks/queries-<size>.md`.
- Without the define, the file registers one skipped test, so CI and a plain `flutter test` never run it.

**Tier 2: the frames, on a phone, in profile mode.** This tier adds two dev dependencies, both from the SDK: `integration_test` and
`flutter_driver`.

- The test is `integration_test/app_benchmark_test.dart`, driven by `test_driver/integration_test.dart`.
- It uses the `benchmarkLive` frame policy: the app and the engine produce the frames, and `pump` only waits.
- It reports three things:
  - `home_data_ms`: from `bootstrap` to the category discs on Home;
  - `transactions_first_rows_ms`: from the tap on the tab to the first row;
  - `transactions_scroll`: `watchPerformance` over 30 flings, load-more included. This gives build and raster time per frame (average,
    p90, p99, worst) and the frames that missed their budget.
- The driver writes `build/integration_response_data.json`.
- Every run passes `--keep-app-running`. Without it, `flutter drive` stops the app and then uninstalls it when the test ends, even after a
  failure (`DriveService.stop` in flutter_tools 3.35.6). On the iPhone that would delete the real data.
- Every run also passes `--no-dds`. `watchPerformance` connects back to the app's own VM Service to read GC counts, and DDS refuses that
  connection.

**Cold start needs no code.** `flutter run --profile --trace-startup` writes `build/start_up_info.json`.

**A benchmark run opens its own database.** On a non-release build with `--dart-define=DATASET`, `GPAppDatabase` opens
`pockit_bench_<size>_v<generator version>` instead of `pockit`.

- The real data is never touched.
- The first launch seeds the file. Later launches reuse it, so the first run's numbers are thrown away.
- `BenchmarkDatasetGenerator.version` goes up whenever the rows change. The next run then gets a fresh file, without uninstalling the app and
  losing the real data with it.

**The reference numbers come from a physical phone.** An emulator or a simulator only shows that the harness runs. The iOS simulator cannot
build in profile mode at all.

The two dependencies, through CLAUDE.md §5's questions:

1. They make the frame timings repeatable on a real phone.
2. Doing it ourselves means reading the timeline through `vm_service` by hand.
3. Both ship with the SDK and the Flutter team maintains them. Their versions follow the SDK, so the 3.35.6 pin holds. A dry run, then
   `pub get`, added six packages and changed none of the existing ones.
4. `integration_test` is a plugin with native parts. iOS gains a pod at the next build, and the plugin registers through the hand-written
   `SceneDelegate` of ADR-0023.
5. They lock nothing in: they are used only in `integration_test/` and `test_driver/`.

## Consequences

Positive:

- Every measurement W9 owes now has a source. Tier 1 needs no device and runs in seconds, so a before/after for an index is one command
  each way.
- The plans sit next to the timings. T5's "which query is slowest, and why" is answered in one file.
- The device run measures what a user waits for, data included, not only the frame cost of a list that is already loaded.

Negative:

- Host numbers come from a JIT Dart on a laptop. Compare them host to host, before against after. Only the device numbers belong in the
  README as what a user sees.
- `home_data_ms` includes all of bootstrap (DI, locale, the category seed, the dataset check), not only the Home queries. Tier 1 isolates
  the queries.
- The time to data is polled every 4 ms, so it is good to within about one frame.
- The benchmark file stays on the phone after the run. Each size takes a few megabytes.

## Alternatives rejected

**Measure frames by hand in DevTools.** It costs nothing to set up, but nobody can repeat a before/after the same way twice.

**Seed the phone's real database.** The seeder refuses to, by design. Wiping the database first would lose the real data.

**One tier, everything on the device.** A query change would then need a profile build and a phone for every comparison. The host tier makes
query work fast to iterate on, and the device tier confirms the result.
