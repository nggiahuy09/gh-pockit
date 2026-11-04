import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/features/transactions/data/seed/benchmark_dataset_size_enum.dart';

void main() {
  test('reads each key the DATASET define takes', () {
    expect(BenchmarkDatasetSize.fromKey('1k'), BenchmarkDatasetSize.k1);
    expect(BenchmarkDatasetSize.fromKey('10k'), BenchmarkDatasetSize.k10);
    expect(BenchmarkDatasetSize.fromKey('50k'), BenchmarkDatasetSize.k50);
  });

  test('reads anything else as no dataset, the empty string of a run without the define included', () {
    expect(BenchmarkDatasetSize.fromKey(''), isNull);
    expect(BenchmarkDatasetSize.fromKey('50K'), isNull);
    expect(BenchmarkDatasetSize.fromKey('50000'), isNull);
  });
}
