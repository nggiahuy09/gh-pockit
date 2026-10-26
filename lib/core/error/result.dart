import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'failure.dart';

/// For outcomes a correct program with a correct user can hit; bugs still throw (ADR-0006).
@immutable
sealed class GPResult<T> with Equatable {
  const GPResult();
}

final class GPOk<T> extends GPResult<T> {
  const GPOk(this.value);

  final T value;

  @override
  List<Object?> get props => [value];
}

final class GPErr<T> extends GPResult<T> {
  const GPErr(this.failure);

  final GPFailure failure;

  @override
  List<Object?> get props => [failure];
}
