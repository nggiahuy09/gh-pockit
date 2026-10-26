import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/money/money.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/entities/account_type.dart';

/// Not a `GPResult`: the user gets the same failure for every bad row, but the log needs the [AccountMapperReason].
sealed class AccountMapping {
  const AccountMapping();
}

final class MappedAccount extends AccountMapping {
  const MappedAccount(this.account);

  final AccountEntity account;
}

final class UnmappableAccountRow extends AccountMapping {
  const UnmappableAccountRow(this.reason);

  final AccountMapperReason reason;

  /// A bad row is unreadable data, not a validation error about a field that is not on screen.
  GPFailure get failure => const GPDatabaseFailure();
}

extension AccountRowMapper on AccountRow {
  /// Maps a tombstone like a live row: the DAO's reads filter them.
  AccountMapping toDomain() {
    final accountType = AccountType.fromStorage(type);
    if (accountType == null) return const UnmappableAccountRow(AccountMapperReason.unknownType);

    // Not the throwing `Money(...)`: a bad code from storage is data, not a bug (ADR-0006).
    final balance = Money.fromStorage(initialBalance, currencyCode);
    if (balance == null) return const UnmappableAccountRow(AccountMapperReason.malformedCurrencyCode);

    final entity = AccountEntity.create(
      initialBalance: balance,
      type: accountType,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt, isUtc: true),
      id: id,
      name: name,
      version: version,
      isArchived: isArchived,
    );

    return switch (entity) {
      GPOk(:final value) => MappedAccount(value),
      GPErr() => const UnmappableAccountRow(AccountMapperReason.brokenDomainRule),
    };
  }
}

extension AccountEntityMapper on AccountEntity {
  /// `.insert`, so a new non-null column is a compile error here until it is set.
  AccountsTableCompanion toInsert(String ownerId) => AccountsTableCompanion.insert(
    id: id,
    ownerId: ownerId,
    name: name,
    type: type.storageValue,
    currencyCode: initialBalance.currencyCode,
    initialBalance: initialBalance.minorUnits,
    isArchived: isArchived,
    createdAt: createdAt.millisecondsSinceEpoch,
    updatedAt: updatedAt.millisecondsSinceEpoch,
    version: version,
  );

  /// User-editable columns only: the currency is fixed at insert (ADR-0010), `version` is the server's, the DAO stamps `updated_at`.
  AccountsTableCompanion toPatch() => AccountsTableCompanion(
    name: Value(name),
    type: Value(type.storageValue),
    initialBalance: Value(initialBalance.minorUnits),
    isArchived: Value(isArchived),
  );
}

/// Goes to the log, so a reason names a check and never a value from the row (golden rule 9).
enum AccountMapperReason { unknownType, malformedCurrencyCode, brokenDomainRule }
