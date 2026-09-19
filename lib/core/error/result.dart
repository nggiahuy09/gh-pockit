import 'package:ghpockit/core/error/failure.dart';
import 'package:meta/meta.dart';

/// The return type of every repository method that can fail in a way the user should hear about (ADR-0006).
///
/// **Why a return type and not an exception.** The local DB is the source of truth and the UI reads a stream off it (golden rule 1), so a successful write
/// announces itself: the stream re-emits and the screen updates without anybody asking. A *failed* write announces nothing — the stream stays silent because
/// nothing changed. That asymmetry is what makes a thrown failure dangerous here in a way it is not in a request/response app: a `BLoC` that forgets a
/// `try/catch` compiles, runs, and leaves the user looking at a screen that did not move, with no error and no change. Put the failure in the return type and
/// the caller cannot reach the value without naming the other branch, so "nothing visibly happened" stops being reachable by omission.
///
/// The second reason is [GPConflictFailure]. Under optimistic versioning (§7) "somebody else changed this row" is an ordinary outcome of a perfectly correct
/// edit, not an exceptional one — on a two-device account it will happen in normal use. Modelling it as a `switch` branch means the UI has to have an answer
/// for it; modelling it as a throw means it arrives at whatever generic handler catches last.
///
/// **What still throws.** Everything that is a bug rather than an outcome: a currency mismatch in `Money` arithmetic, a null that should not be null, a
/// broken invariant. Those are `Error`s, they have no user-facing message, and wrapping them here would only teach callers to handle them — which is the
/// opposite of what should happen to a bug. The line is: *could a correct program with a correct user produce this?* Yes → [GPResult]. No → throw.
///
/// **Why not `dartz`/`fpdart`.** §5 asks what it would cost to do it ourselves; the answer is this file. `Either<L, R>` would also bring a vocabulary
/// (`fold`, `bimap`, monad transformers) that this codebase would use inconsistently, and `Left`/`Right` are strictly worse at a call site than [GPOk] and
/// [GPErr] — one has to remember that failure conventionally sits on the left, the other says so.
@immutable
sealed class GPResult<T> {
  const GPResult();
}

/// The operation succeeded and produced [value].
///
/// For an operation with nothing to hand back, the type argument is `void` and the value is null: `const GPOk<void>(null)`. That is deliberately not hidden
/// behind a `Unit` type — one `null` at a handful of call sites is cheaper than a new concept.
final class GPOk<T> extends GPResult<T> {
  const GPOk(this.value);

  final T value;

  /// Value equality, so a test can write `expect(result, GPOk(expectedAccount))` and get a readable diff instead of an identity mismatch. It only holds as
  /// far as `T` itself has value equality — which is why `AccountEntity` and `Money` both implement `==`.
  @override
  bool operator ==(Object other) => identical(this, other) || other is GPOk<T> && other.value == value;

  @override
  int get hashCode => Object.hash(GPOk<T>, value);

  @override
  String toString() => 'GPOk<$T>($value)';
}

/// The operation failed, and [failure] says how.
///
/// The payload is a [GPFailure] rather than a message: the domain and data layers do not know the active language, and presentation maps the type through
/// `failure_message.dart` (ADR-0004).
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
