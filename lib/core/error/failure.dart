import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Carries a type, never a message: presentation maps it to `l10n.error.*` (ADR-0004).
@immutable
sealed class GPFailure with Equatable {
  const GPFailure();

  @override
  List<Object?> get props => const [];
}

final class GPNetworkFailure extends GPFailure {
  const GPNetworkFailure();
}

/// Unlike [GPNetworkFailure], the server may have applied the write: a retry must reuse the idempotency key.
final class GPTimeoutFailure extends GPFailure {
  const GPTimeoutFailure();
}

/// HTTP 401: the one 4xx with a refresh flow.
final class GPAuthenticationFailure extends GPFailure {
  const GPAuthenticationFailure();
}

/// HTTP 403: never retried.
final class GPAuthorizationFailure extends GPFailure {
  const GPAuthorizationFailure();
}

final class GPValidationFailure extends GPFailure {
  const GPValidationFailure(this.code);

  final GPValidationCode code;

  @override
  List<Object?> get props => [code];
}

final class GPConflictFailure extends GPFailure {
  const GPConflictFailure({required this.entityId, required this.localVersion, required this.remoteVersion});

  final String entityId;
  final int localVersion;
  final int remoteVersion;

  @override
  List<Object?> get props => [entityId, localVersion, remoteVersion];
}

final class GPNotFoundFailure extends GPFailure {
  const GPNotFoundFailure();
}

final class GPDatabaseFailure extends GPFailure {
  const GPDatabaseFailure();
}

final class GPUnknownFailure extends GPFailure {
  const GPUnknownFailure();
}

enum GPValidationCode {
  accountNameEmpty,
  accountNameTooLong,

  /// Checked by `DeleteAccountUseCase`, not the entity (ADR-0010).
  accountHasTransactions,

  categoryNameEmpty,
  categoryNameTooLong,
  transactionAmountNotPositive,
  transactionDestinationMissing,
  transactionDestinationSameAsSource,
  transactionNoteTooLong,

  /// Balances are a SQL `SUM`, so `Money` cannot catch it (ADR-0010).
  transactionCurrencyMismatch,

  transactionTransferCurrenciesDiffer,

  /// Checked by the use cases: it needs the category row (ADR-0010).
  transactionCategoryTypeMismatch,
}
