import 'package:meta/meta.dart';

/// Carries a type, never a message: presentation maps it to `l10n.error.*` (ADR-0004).
@immutable
sealed class GPFailure {
  const GPFailure();
}

final class GPNetworkFailure extends GPFailure {
  const GPNetworkFailure();
}

/// Unlike [GPNetworkFailure], the server may have applied the write: a retry must reuse the idempotency key.
final class GPTimeoutFailure extends GPFailure {
  const GPTimeoutFailure();
}

/// HTTP 401: the one 4xx with a refresh flow, so not terminal.
final class GPAuthenticationFailure extends GPFailure {
  const GPAuthenticationFailure();
}

/// HTTP 403: re-authenticating fixes nothing, so never retried.
final class GPAuthorizationFailure extends GPFailure {
  const GPAuthorizationFailure();
}

enum GPValidationCode {
  /// Also whitespace-only: names are trimmed before the check.
  accountNameEmpty,

  accountNameTooLong,

  /// A live transaction touches the account, on either side of a transfer. Checked by `DeleteAccountUseCase`, not the entity (ADR-0010).
  accountHasTransactions,

  /// Neither a `name_key` (seeded) nor a typed name.
  categoryNameEmpty,

  categoryNameTooLong,

  /// The amount is a magnitude; the type gives the direction (ADR-0009).
  transactionAmountNotPositive,

  transactionDestinationMissing,

  transactionDestinationSameAsSource,

  transactionNoteTooLong,

  /// `Money` cannot catch this, because balances are a SQL `SUM` (ADR-0010). A correct user can hit it: another device may change the account mid-edit.
  transactionCurrencyMismatch,

  transactionTransferCurrenciesDiffer,

  /// Checked by the use cases, not the entity: it needs the category's row (ADR-0010).
  transactionCategoryTypeMismatch,
}

final class GPValidationFailure extends GPFailure {
  const GPValidationFailure(this.code);

  final GPValidationCode code;

  /// Only failures with fields need `==`: the fieldless ones are `const`, so identity already is equality.
  @override
  bool operator ==(Object other) => identical(this, other) || other is GPValidationFailure && other.code == code;

  @override
  int get hashCode => Object.hash(GPValidationFailure, code);

  @override
  String toString() => 'GPValidationFailure(code: ${code.name})';
}

final class GPConflictFailure extends GPFailure {
  const GPConflictFailure({required this.entityId, required this.localVersion, required this.remoteVersion});

  final String entityId;
  final int localVersion;
  final int remoteVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GPConflictFailure && other.entityId == entityId && other.localVersion == localVersion && other.remoteVersion == remoteVersion;

  @override
  int get hashCode => Object.hash(entityId, localVersion, remoteVersion);

  @override
  String toString() => 'GPConflictFailure(entityId: $entityId, localVersion: $localVersion, remoteVersion: $remoteVersion)';
}

/// Deleted or never there. Routine across devices, so not worth a crash report.
final class GPNotFoundFailure extends GPFailure {
  const GPNotFoundFailure();
}

final class GPDatabaseFailure extends GPFailure {
  const GPDatabaseFailure();
}

/// Last resort: a case that keeps showing up here deserves its own subtype.
final class GPUnknownFailure extends GPFailure {
  const GPUnknownFailure();
}
