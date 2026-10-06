import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';

void main() {
  group('GPOk', () {
    test('is equal by value', () {
      expect(const GPOk<int>(1), const GPOk<int>(1));
      expect(const GPOk<int>(1).hashCode, const GPOk<int>(1).hashCode);
      expect(const GPOk<int>(1), isNot(const GPOk<int>(2)));
    });

    test('carries void for an operation with nothing to return', () {
      // `const GPOk<void>(null)` looks like it should not compile; `archiveAccount` and friends rely on it.
      const GPResult<void> result = GPOk<void>(null);

      expect(result, isA<GPOk<void>>());
    });
  });

  group('GPErr', () {
    test('is equal by value, through the failure it carries', () {
      expect(const GPErr<int>(GPNetworkFailure()), const GPErr<int>(GPNetworkFailure()));
      expect(const GPErr<int>(GPNetworkFailure()), isNot(const GPErr<int>(GPTimeoutFailure())));
    });

    test('compares two validation codes apart', () {
      expect(
        const GPErr<int>(GPValidationFailure(GPValidationCode.accountNameEmpty)),
        const GPErr<int>(GPValidationFailure(GPValidationCode.accountNameEmpty)),
      );
      expect(
        const GPErr<int>(GPValidationFailure(GPValidationCode.accountNameEmpty)),
        isNot(const GPErr<int>(GPValidationFailure(GPValidationCode.accountNameTooLong))),
      );
    });
  });

  test('an ok and an err are never equal', () {
    expect(const GPOk<int>(1), isNot(const GPErr<int>(GPNetworkFailure())));
  });

  test('a switch over a result is exhaustive without a default branch', () {
    const results = <GPResult<int>>[GPOk<int>(7), GPErr<int>(GPDatabaseFailure())];

    final described = results
        .map(
          (result) => switch (result) {
            GPOk<int>(:final value) => 'ok:$value',
            GPErr<int>(:final failure) => 'err:${failure.runtimeType}',
          },
        )
        .toList();

    expect(described, ['ok:7', 'err:GPDatabaseFailure']);
  });
}
