import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:meta/meta.dart';

/// A place money sits: a wallet, a bank account, an e-wallet, a credit card (blueprint §Accounts).
///
/// The first domain entity in the app, and therefore the first place the three-model rule (§3) becomes visible rather than theoretical. `AccountRow` is what
/// SQLite holds, `AccountDto` will be what Supabase sends, and this is what the rest of the app reasons about. The three deliberately disagree:
///
/// | Row has | Entity has | Why they differ |
/// | --- | --- | --- |
/// | `ownerId` | — | Row-level ownership is a persistence and RLS concern. The repository knows the owner (`localOwnerId` now, the session uid at W10) and scopes every query with it; nothing in the domain branches on it, and putting it here would invite a `BLoC` to pass one in. |
/// | `deletedAt` | — | A tombstone is not an account. `deleted_at IS NULL` is filtered in the DAO, so an [AccountEntity] that exists is an account that exists; soft delete is an operation on the repository, not a state of the entity. |
/// | `int createdAt` | `DateTime createdAt` | §6 stores epoch millis; a domain that has to remember which integer is a date is a domain doing the mapper's job. `AccountMapper` (T6) converts. |
/// | `int initialBalance` + `String currencyCode` | one [Money] | An amount and its currency travelling separately is exactly how a VND number ends up rendered as dollars. |
/// | `version` | `version` | The one persistence field that *is* domain-visible, because §7 makes it so: an edit carries its `baseVersion`, and a conflict is a user-facing outcome. |
///
/// Immutable, like every entity here. An edit produces a new instance through [update], so a `BLoC` state holding an [AccountEntity] cannot be mutated out from
/// under the widget that is rendering it, and `flutter_bloc`'s equality check on state stays meaningful.
@immutable
final class AccountEntity {
  const AccountEntity._({
    required this.id,
    required this.name,
    required this.type,
    required this.initialBalance,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  /// Longest account name accepted, in UTF-16 code units.
  ///
  /// A limit exists because `accounts.name` is unbounded `TEXT` that syncs: without one, a paste of a whole document becomes a row pushed to the server and
  /// pulled onto every other device. 100 is generous for "Vietcombank", "Ví tiền mặt" or "Thẻ tín dụng Techcombank" and small enough to stay a sane column.
  ///
  /// Code units, not grapheme clusters, so an emoji counts as two and a flag as four. Counting what a user would call characters needs `package:characters`
  /// and a dependency §5 would have to justify; at this limit the difference is never the thing that stops a legitimate name.
  static const int nameMaxLength = 100;

  final String id;

  /// Already trimmed — [create] is the only way in and it trims. So a caller never has to wonder whether `' Ví '` and `'Ví'` are two accounts.
  final String name;

  final AccountType type;

  /// The *opening* balance, not the current one. The current balance is `initialBalance + SUM(transactions)`, computed over an index (§6, §12.8) — storing it
  /// here would be the derived-column anti-pattern with no recompute strategy.
  final Money initialBalance;

  /// Out of pickers and out of the list, but still syncing and still owning its transactions. Distinct from deleted; see the class doc.
  final bool isArchived;

  /// UTC, always. [create] normalises, so no caller has to check `isUtc`.
  final DateTime createdAt;

  /// UTC. Half the pull cursor at W12 T2, which is why it is stamped by the repository from `GPClock` rather than defaulted anywhere.
  final DateTime updatedAt;

  /// Optimistic-concurrency token (§7). The server's number: the client sends it back as `baseVersion` and never increments it hopefully — a client-invented
  /// version is a base the server never issued, so every edit after it would report a conflict that is not one.
  final int version;

  /// The only way to build an [AccountEntity], and the only place the two name rules live.
  ///
  /// Returns a [GPResult] rather than throwing because a blank name is something a correct user does by ordinary typing — ADR-0006's dividing line. The
  /// caller gets a [GPValidationCode] that names the field, so the form can put the message under the right input instead of showing "check your input".
  ///
  /// **Used by the mapper too**, not just by create-account. Reconstructing an entity from a row runs the same validation, so a row that went bad — hand-edited
  /// during debugging, written by a build that predates a rule — is caught at the boundary instead of flowing into the UI as an account with no name.
  ///
  /// [createdAt] and [updatedAt] are required with no default, for the reason `AccountDao` makes `now` required: the repository reads `GPClock` once and
  /// passes the same instant to the entity and to the `sync_mutations` row it writes in the same transaction (golden rule 3). A default here would let the
  /// entity invent a second, slightly different "now".
  static GPResult<AccountEntity> create({
    required String id,
    required String name,
    required AccountType type,
    required Money initialBalance,
    required DateTime createdAt,
    required DateTime updatedAt,
    bool isArchived = false,
    int version = 1,
  }) {
    // Trim first, then test: `'   '` is a blank name, not a three-character one, and a name that survives arrives already normalised.
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      return const GPErr<AccountEntity>(GPValidationFailure(GPValidationCode.accountNameEmpty));
    }

    if (trimmedName.length > nameMaxLength) {
      return const GPErr<AccountEntity>(GPValidationFailure(GPValidationCode.accountNameTooLong));
    }

    return GPOk<AccountEntity>(
      AccountEntity._(
        id: id,
        name: trimmedName,
        type: type,
        initialBalance: initialBalance,
        isArchived: isArchived,
        // Normalised here rather than asserted, so a caller that hands over a local `DateTime` gets the right instant instead of a failed test later. §6
        // keeps timezones out of storage entirely; the device zone is a presentation concern.
        createdAt: createdAt.toUtc(),
        updatedAt: updatedAt.toUtc(),
        version: version,
      ),
    );
  }

  /// A copy with some fields changed, re-validated.
  ///
  /// Returns a [GPResult] for the same reason [create] does: renaming to `''` is a user action, not a bug, and it has to produce a message rather than a
  /// thrown error. This is the call a form makes on submit, so the failure lands where the user is looking — under the field — before anything touches
  /// storage.
  ///
  /// [id] and [createdAt] are absent on purpose: an entity that can change its own identity or its own birth date is one the sync engine can no longer
  /// match against a server row.
  ///
  /// **[updatedAt] is absent too, and that is the load-bearing one.** It was a required parameter when this was written and it was the wrong shape: the
  /// only correct value is "now", the only holder of "now" is `GPClock`, and the only layer that has one is the repository — which meant every caller
  /// invented a timestamp that `AccountRepositoryImpl` then threw away. A parameter whose every value is discarded is a parameter that will eventually be
  /// believed. Restamping is [stampedAt], the repository calls it, and nothing else needs to.
  ///
  /// [version] is settable because the *server* sets it — the repository writes the number that came back on a push. Nothing else should pass it.
  GPResult<AccountEntity> update({String? name, AccountType? type, Money? initialBalance, bool? isArchived, int? version}) => create(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    initialBalance: initialBalance ?? this.initialBalance,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isArchived: isArchived ?? this.isArchived,
    version: version ?? this.version,
  );

  /// The same account with a new [updatedAt]. Cannot fail, because nothing validated changes.
  ///
  /// The repository's half of the split above: [update] decides *what* the account says, this decides *when* it last said it. Keeping them apart is what
  /// makes "an edit always moves the pull cursor" true by construction — there is no path that changes a field without going through the repository, and
  /// the repository has no path that writes without calling this.
  ///
  /// Not a [GPResult], on purpose. Wrapping an operation that cannot fail would make callers write a branch that can never be taken, and a branch that can
  /// never be taken is one nobody keeps correct.
  AccountEntity stampedAt(DateTime updatedAt) => AccountEntity._(
    id: id,
    name: name,
    type: type,
    initialBalance: initialBalance,
    isArchived: isArchived,
    createdAt: createdAt,
    updatedAt: updatedAt.toUtc(),
    version: version,
  );

  /// Value equality over every field.
  ///
  /// Not a nicety: `flutter_bloc` skips a rebuild when the new state equals the old one, and a list of accounts re-emitted by a Drift stream after an
  /// unrelated write produces freshly mapped instances every time. Without this, every write to `accounts` would rebuild every account widget on screen.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountEntity &&
          other.id == id &&
          other.name == name &&
          other.type == type &&
          other.initialBalance == initialBalance &&
          other.isArchived == isArchived &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt &&
          other.version == version;

  @override
  int get hashCode => Object.hash(id, name, type, initialBalance, isArchived, createdAt, updatedAt, version);

  /// **Carries no name and no balance, deliberately.** Golden rule 9 allows a log line to hold an id, an entity type and an error code; an account name is
  /// user data and a balance is a financial payload. This entity will be interpolated into sync and repository logs, so the safe thing has to be the default
  /// thing — `redactSensitiveFields` only sees maps, not a string somebody already built. `account_entity_test.dart` guards it, the same way `failure_test.dart`
  /// guards `GPConflictFailure.toString`.
  @override
  String toString() => 'AccountEntity(id: $id, type: ${type.name}, isArchived: $isArchived, version: $version)';
}
