import 'package:drift/drift.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';

/// Why a stored row could not be read.
///
/// **The user never sees this; a log line does.** Every value here flattens to the same [GPDatabaseFailure] on the way out (see [AccountMapper.toEntity]),
/// because "local data cannot be read" is the only true sentence to show someone who is looking at a list. But they are three different bugs, and merging
/// them in the log too would leave P7's crash reports with one undifferentiated cluster and no way to tell a schema drift from a corrupted file.
///
/// A reason is exactly what golden rule 9 allows a log to carry: it names a *check*, not a value. Nothing here can leak a name, an amount or a currency.
enum AccountMapperReason {
  /// `type` held a string no [AccountType] knows — a row from a newer build, or a corrupted one.
  unknownType,

  /// `currency_code` was not three A–Z letters, which makes `initial_balance` un-interpretable rather than merely wrong.
  malformedCurrencyCode,

  /// The row parsed but broke a domain rule — a blank name, today. Reachable only if a row was written by something that bypassed [AccountEntity].
  brokenDomainRule,
}

/// The outcome of reading one `accounts` row.
///
/// A sealed pair rather than a `GPResult<AccountEntity>`, and the difference is the reason: `GPResult` carries a [GPFailure], which is the *user-facing*
/// vocabulary, and the user-facing answer here is always the same one. What varies is what the log should say. Keeping them apart means the flattening is
/// stated once, in [UnmappableAccountRow.failure], instead of being re-decided at every call site — and it means adding a reason without deciding what is
/// logged for it does not compile.
sealed class AccountMapping {
  const AccountMapping();
}

/// The row was read.
final class MappedAccount extends AccountMapping {
  const MappedAccount(this.account);

  final AccountEntity account;
}

/// The row was not read, and [reason] says which check refused it.
final class UnmappableAccountRow extends AccountMapping {
  const UnmappableAccountRow(this.reason);

  final AccountMapperReason reason;

  /// Always [GPDatabaseFailure], whatever the reason.
  ///
  /// The single place that flattening happens. A blank `name` in a *row* is not the same event as a blank name in a text field: the user is not typing,
  /// they are looking at a list, and "Account name can't be empty" would be a sentence about an input that is not on screen. What actually happened is that
  /// local data cannot be read — which is loud on purpose, because golden rule 1 leaves no remote copy to fall back to.
  GPFailure get failure => const GPDatabaseFailure();
}

/// The one place that knows how an `accounts` row becomes an [AccountEntity] and back (W2 T6).
///
/// The three-model rule (§3) says the row and the entity are allowed to disagree; this is where that disagreement is paid for. Four translations happen
/// here and nowhere else:
///
/// - **`type` ↔ `AccountType`** through `storageValue`, not through drift's `textEnum`. The table refuses `textEnum` precisely so a Dart rename cannot
///   silently orphan every row, and the price of that refusal is this conversion.
/// - **`initial_balance` + `currency_code` ↔ one [Money]**. Two columns, one value object: the amount and its currency are separable in SQLite and must not
///   be separable anywhere above it.
/// - **epoch millis ↔ `DateTime`**, always UTC (§6).
/// - **`owner_id` appears out of nowhere.** It is not on the entity (see [AccountEntity]'s class doc), so [toInsert] takes it as an argument and the
///   repository is the only caller that can supply it.
///
/// **Row → entity can fail; entity → row cannot.** Everything the entity holds is already valid by construction, so building a companion is a pure rename
/// of fields. Reading a row is parsing: the `type` string may be a value this build does not know, and the currency code may not be a currency code.
///
/// Stateless and `const`, so the repository holds one as a default argument rather than DI registering it. There is nothing to configure and nothing to
/// fake — a test that wanted a "broken mapper" would be testing the mapper, and it should test it directly.
class AccountMapper {
  const AccountMapper();

  /// Parses a row into a [MappedAccount], or an [UnmappableAccountRow] naming the check that refused it.
  ///
  /// Tombstones are **not** filtered here. [AccountEntity] has no `deletedAt`, so a soft-deleted row maps to an entity that looks alive; every read path in
  /// `AccountDao` already filters `deleted_at IS NULL`, and the one that does not — `findById` — exists for W13's applier, which wants the tombstone. Putting
  /// the filter here as well would make the applier unable to use the mapper at all.
  AccountMapping toEntity(AccountRow row) {
    final type = AccountType.fromStorage(row.type);
    if (type == null) {
      // A value this build does not know: either a corrupt row or one written by a newer version. Both are unreadable data, and both must not be silently
      // coerced to `other` — see `AccountType.fromStorage`.
      return const UnmappableAccountRow(AccountMapperReason.unknownType);
    }

    // `Money.fromStorage`, not the throwing `Money(...)`. A malformed currency code is a bug when the program produces one and *data* when SQLite hands
    // one back, and this is the boundary between those two readings (ADR-0006). Catching an `ArgumentError` here instead would be catching an `Error`,
    // which is the thing that line exists to forbid.
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
      // The domain's own [GPValidationFailure] is deliberately dropped rather than forwarded — see [UnmappableAccountRow.failure].
      GPErr<AccountEntity>() => const UnmappableAccountRow(AccountMapperReason.brokenDomainRule),
    };
  }

  /// Builds the companion for a fresh insert — every column stated, nothing defaulted.
  ///
  /// `AccountsTableCompanion.insert` rather than the unnamed constructor, so a column added to the table without a value here is a compile error instead of
  /// an absent value. That is the same guarantee the table's "no SQL defaults, deliberately" note is protecting: on a synced row, a value nobody wrote is
  /// indistinguishable from a value the server confirmed.
  ///
  /// [ownerId] comes from the repository — `localOwnerId` today, the session uid at W10.
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

  /// Builds the patch for an update: only the columns a user edit may move.
  ///
  /// Four columns are absent and each for its own reason. `id` and `created_at` are identity — an entity that could change them is one the sync engine can
  /// no longer match to a server row. `owner_id` is not the entity's to state. `version` is the server's (§7), and `updated_at` is stamped by
  /// `AccountDao.updateAccount` itself so that a patch cannot skip the pull cursor.
  AccountsTableCompanion toPatch(AccountEntity entity) => AccountsTableCompanion(
    name: Value(entity.name),
    type: Value(entity.type.storageValue),
    currencyCode: Value(entity.initialBalance.currencyCode),
    initialBalance: Value(entity.initialBalance.minorUnits),
    isArchived: Value(entity.isArchived),
  );
}
