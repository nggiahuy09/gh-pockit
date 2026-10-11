import 'package:drift/drift.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';

enum AccountMapperReason {
  unknownType,
  malformedCurrencyCode,
  brokenDomainRule,
}

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

  /// Always [GPDatabaseFailure]: a bad row is unreadable data, not a validation error about a field that is not on screen.
  GPFailure get failure => const GPDatabaseFailure();
}

class AccountMapper {
  const AccountMapper();

  /// Does not filter tombstones: a soft-deleted row maps to an entity that looks alive.
  AccountMapping toEntity(AccountRow row) {
    final type = AccountType.fromStorage(row.type);
    if (type == null) {
      return const UnmappableAccountRow(AccountMapperReason.unknownType);
    }

    // Not the throwing `Money(...)`: a bad code from storage is data, not a bug (ADR-0006).
    final initialBalance = Money.fromStorage(row.initialBalance, row.currencyCode);
    if (initialBalance == null) {
      return const UnmappableAccountRow(AccountMapperReason.malformedCurrencyCode);
    }

    final entity = AccountEntity.create(
      id: row.id,
      name: row.name,
      type: type,
      initialBalance: initialBalance,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
      isArchived: row.isArchived,
      version: row.version,
    );

    return switch (entity) {
      GPOk<AccountEntity>(:final value) => MappedAccount(value),
      GPErr<AccountEntity>() => const UnmappableAccountRow(AccountMapperReason.brokenDomainRule),
    };
  }

  /// `.insert`, so a non-null column added to the table is a compile error here until it is set.
  AccountsTableCompanion toInsert(AccountEntity entity, {required String ownerId}) => AccountsTableCompanion.insert(
    id: entity.id,
    ownerId: ownerId,
    name: entity.name,
    type: entity.type.storageValue,
    currencyCode: entity.initialBalance.currencyCode,
    initialBalance: entity.initialBalance.minorUnits,
    isArchived: entity.isArchived,
    createdAt: entity.createdAt.millisecondsSinceEpoch,
    updatedAt: entity.updatedAt.millisecondsSinceEpoch,
    version: entity.version,
  );

  /// User-editable columns only: `version` is the server's, and `AccountDao.updateAccount` stamps `updated_at`.
  AccountsTableCompanion toPatch(AccountEntity entity) => AccountsTableCompanion(
    name: Value(entity.name),
    type: Value(entity.type.storageValue),
    currencyCode: Value(entity.initialBalance.currencyCode),
    initialBalance: Value(entity.initialBalance.minorUnits),
    isArchived: Value(entity.isArchived),
  );
}
