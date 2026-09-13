/// Reads the current time.
///
/// Everything in this app that needs "now" — `created_at`, `updated_at`,
/// `occurred_at` defaults, retry backoff, `next_attempt_at` on a sync mutation
/// — goes through this interface instead of calling `DateTime.now()`.
///
/// The reason is testability, not purity. A sync-engine test has to assert
/// things like "after two failures the mutation is not retried for 4 seconds".
/// With `DateTime.now()` that test can only be written with a real
/// `Future.delayed`, which CLAUDE.md §8 forbids: it makes the suite slow and
/// flaky. With a `GPClock` the test advances a fake clock and stays instant and deterministic.
///
/// Time is always handled in UTC. The device timezone is a presentation
/// concern; it must never reach the database (CLAUDE.md §6 stores timestamps as epoch millis) or the wire.
abstract class GPClock {
  const GPClock();

  /// Current instant, always with `isUtc == true`.
  DateTime nowUtc();

  /// Current instant as milliseconds since the Unix epoch — the exact shape stored in `INTEGER` timestamp columns, so persistence code does not have
  /// to remember the `.toUtc().millisecondsSinceEpoch` dance.
  int nowEpochMillis();
}

/// The real clock. The only implementation registered in production DI.
class GPSystemClock extends GPClock {
  const GPSystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  // `millisecondsSinceEpoch` is timezone-independent by definition, so this needs no `toUtc()` — the epoch is the same instant everywhere.
  int nowEpochMillis() => DateTime.now().millisecondsSinceEpoch;
}
