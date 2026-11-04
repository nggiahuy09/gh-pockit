/// Picked by `--dart-define=DATASET=<key>`.
enum BenchmarkDatasetSize {
  k1('1k', 1000),
  k10('10k', 10000),
  k50('50k', 50000);

  const BenchmarkDatasetSize(this.key, this.count);

  final String key;
  final int count;

  static BenchmarkDatasetSize? fromKey(String value) => values.where((size) => size.key == value).firstOrNull;
}
