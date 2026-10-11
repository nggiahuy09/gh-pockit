import 'package:ghpockit/core/error/failure.dart';
import 'package:meta/meta.dart';

/// For outcomes a correct program with a correct user can hit; bugs still throw (ADR-0006).
@immutable
sealed class GPResult<T> {
  const GPResult();
}

final class GPOk<T> extends GPResult<T> {
  const GPOk(this.value);

  final T value;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GPOk<T> && other.value == value;

  @override
  int get hashCode => Object.hash(GPOk<T>, value);

  @override
  String toString() => 'GPOk<$T>($value)';
}

final class GPErr<T> extends GPResult<T> {
  const GPErr(this.failure);

  final GPFailure failure;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GPErr<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(GPErr<T>, failure);

  @override
  String toString() => 'GPErr<$T>($failure)';
}
