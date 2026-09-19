import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';

/// ADR-0006's return type under test.
///
/// Most of its value is a compile-time property — a caller cannot reach the value without naming the failure branch — and a test cannot assert that. What
/// is asserted here is the part that would silently rot: equality, so `expect(result, GPOk(account))` compares what it looks like it compares.
void main() {
  group('GPOk', () {
    test('is equal by value', () {
      expect(const GPOk<int>(1), const GPOk<int>(1));
      expect(const GPOk<int>(1).hashCode, const GPOk<int>(1).hashCode);
      expect(const GPOk<int>(1), isNot(const GPOk<int>(2)));
    });

    test('carries void for an operation with nothing to return', () {
      // `archiveAccount` and friends return `GPResult<void>`. Asserted because `const GPOk<void>(null)` is the one call shape that looks like it should
      // not compile.
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
      // The case the new `operator ==` on GPValidationFailure exists for: without it these would be distinct runtime objects and every form-validation
      // expectation would fail for the wrong reason.
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
    // The whole point of `sealed`, and the reason this compiles: adding a third subtype would break every switch that has to care.
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
