import 'package:meta/meta.dart';

/// Everything that can go wrong, as a closed set of types.
///
/// `sealed` is the point. The compiler knows the complete list of subtypes, so a `switch` over a `GPFailure` that forgets a case is a compile error
/// instead of a silent fallthrough to "Something went wrong". That is also what makes it safe to add a failure later: the new subtype breaks every
/// switch that has to care, and the analyzer names them.
///
/// **A failure carries a type, never a message** (ADR-0004). Appendix B of the blueprint had `ValidationFailure(this.message)`; that field is
/// deliberately absent here. A message would have to be written by whoever constructs the failure — the domain or the data layer — and neither of
/// them knows the active language. Presentation maps the type to `l10n.error.*` instead; see `failure_message.dart`.
///
/// No Flutter import, on purpose: `domain/` is allowed to depend on this file (CLAUDE.md §3), and the moment it pulls in `widgets.dart` that rule is
/// gone. `@immutable` therefore comes from `package:meta` rather than `package:flutter/foundation.dart`, and it sits on the sealed base so the
/// analyzer holds every present and future subtype to it — a failure that can be mutated after the fact would make retry and conflict handling
/// unreadable.
@immutable
sealed class GPFailure {
  const GPFailure();
}

/// The request never left the device, or never got an answer back.
///
/// Retryable (CLAUDE.md §7). Note what this does *not* mean: `connectivity_plus` reporting "offline" is a signal, not a failure — only a real request
/// produces one of these.
final class GPNetworkFailure extends GPFailure {
  const GPNetworkFailure();
}

/// The request was sent and the deadline passed with no response.
///
/// Kept separate from [GPNetworkFailure] even though both are retryable, because a timeout says the server may well have applied the write. That is
/// exactly the case idempotency keys exist for, and a sync test asserting "a timed-out push is retried with the same key" has to be able to name it.
final class GPTimeoutFailure extends GPFailure {
  const GPTimeoutFailure();
}

/// Not signed in, or the session expired — HTTP 401.
///
/// The one 4xx that is not terminal: it has a refresh flow (CLAUDE.md §7). Everything else in the 4xx range is a bug on the client side and must not
/// be retried.
final class GPAuthenticationFailure extends GPFailure {
  const GPAuthenticationFailure();
}

/// Signed in as somebody who may not touch this row — HTTP 403.
///
/// Distinct from [GPAuthenticationFailure] because re-authenticating fixes nothing here. Retrying is pointless; on a row-level-security backend this
/// usually means an `owner_id` mismatch, which is a data bug worth surfacing rather than swallowing.
final class GPAuthorizationFailure extends GPFailure {
  const GPAuthorizationFailure();
}

/// A domain rule said no. The write never reached persistence.
///
/// Fieldless today because there are no domain rules yet — W1 has no entities. The first real rule lands in W4 ("a transfer needs a destination
/// account, and it must differ from the source"), and that is the moment to add a `GPValidationCode` enum with one `l10n.error.*` getter per code.
/// Inventing that enum now would mean guessing the rules, which is the day-one over-engineering CLAUDE.md §12.11 rejects.
final class GPValidationFailure extends GPFailure {
  const GPValidationFailure();
}

/// The server refused a write because the row moved on since this client last read it.
///
/// Optimistic versioning: the client sends `baseVersion`, the server runs `UPDATE ... WHERE version = ?`, and zero affected rows is this (CLAUDE.md
/// §7). The only failure carrying data, because the conflict resolver needs it — and none of that data is a message or a financial value, so golden
/// rule 9 is satisfied: an id and two integers are exactly what a log line is allowed to hold.
final class GPConflictFailure extends GPFailure {
  const GPConflictFailure({required this.entityId, required this.localVersion, required this.remoteVersion});

  final String entityId;
  final int localVersion;
  final int remoteVersion;

  /// Value equality, unlike every other failure here. The fieldless ones are `const` and therefore canonicalised by the compiler, so identity already
  /// is equality for them. This one is built at runtime from real version numbers, so without this two conflicts describing the same row would
  /// compare unequal and every `expect(result, GPConflictFailure(...))` in a sync test would fail for the wrong reason.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GPConflictFailure && other.entityId == entityId && other.localVersion == localVersion && other.remoteVersion == remoteVersion;

  @override
  int get hashCode => Object.hash(entityId, localVersion, remoteVersion);

  @override
  String toString() => 'GPConflictFailure(entityId: $entityId, localVersion: $localVersion, remoteVersion: $remoteVersion)';
}

/// The local database could not be read or written.
///
/// This one is louder than it looks. The local DB is the source of truth for the UI (golden rule 1), so a failure here is not a degraded-offline
/// state the app can shrug off — there is no remote copy to fall back to by design.
final class GPDatabaseFailure extends GPFailure {
  const GPDatabaseFailure();
}

/// Nothing above matched.
///
/// Deliberately the last resort and not a default: because [GPFailure] is sealed, no switch is ever *forced* to route an unhandled case here. If this
/// starts showing up in crash reports for a case that has a name, the fix is a new subtype, not a better message.
final class GPUnknownFailure extends GPFailure {
  const GPUnknownFailure();
}
