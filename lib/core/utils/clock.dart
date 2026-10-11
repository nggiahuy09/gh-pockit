/// The only source of "now": app code never calls `DateTime.now()`, so tests can fake time.
abstract class GPClock {
  const GPClock();

  DateTime nowUtc();

  int nowEpochMillis();
}

class GPSystemClock extends GPClock {
  const GPSystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  // Epoch millis are the same in every timezone, so no `toUtc()`.
  int nowEpochMillis() => DateTime.now().millisecondsSinceEpoch;
}
