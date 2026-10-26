import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/result.dart';

/// The value of a result the test expects to succeed, without an `as GPOk<T>` cast.
T okValue<T>(GPResult<T> result) => switch (result) {
  GPOk(:final value) => value,
  GPErr(:final failure) => throw TestFailure('Expected GPOk, got GPErr($failure)'),
};
