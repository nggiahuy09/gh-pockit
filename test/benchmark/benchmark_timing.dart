/// Microsecond samples of one case, sorted.
final class BenchmarkTiming {
  BenchmarkTiming(List<int> samples) : _samples = [...samples]..sort();

  final List<int> _samples;

  int get medianMicros => _samples[_samples.length ~/ 2];

  int get p90Micros => _samples[((_samples.length - 1) * 0.9).round()];

  int get maxMicros => _samples.last;
}

/// The warm-up runs are thrown away, so the JIT and SQLite's page cache are warm before anything counts.
Future<BenchmarkTiming> measure(Future<Object?> Function() run, {int runs = 30, int warmUpRuns = 5}) async {
  final samples = <int>[];
  for (var i = 0; i < warmUpRuns + runs; i++) {
    final stopwatch = Stopwatch()..start();
    await run.call();
    if (i >= warmUpRuns) samples.add(stopwatch.elapsedMicroseconds);
    // Lets drift drop the stream it caches for a moment after the last listener leaves, so the next `watch().first` runs the query again.
    await Future<void>.delayed(Duration.zero);
  }

  return BenchmarkTiming(samples);
}

String millis(int micros) => (micros / 1000).toStringAsFixed(2);
