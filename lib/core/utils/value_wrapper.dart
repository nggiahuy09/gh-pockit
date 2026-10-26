import 'package:meta/meta.dart';

/// Lets a `copyWith` tell "set to null" from "keep": pass `GPValueWrapper(null)` to clear.
@immutable
final class GPValueWrapper<T> {
  const GPValueWrapper(this.value);

  final T value;
}
