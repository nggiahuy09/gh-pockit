import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:meta/meta.dart';

/// No `ownerId` or `deletedAt`: the repository scopes by owner and the DAO filters out tombstones.
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

  /// In UTF-16 code units, so an emoji counts as two.
  static const int nameMaxLength = 100;

  final String id;

  /// Trimmed. Not unique, on purpose: two wallets may share a name.
  final String name;

  final AccountType type;

  /// The opening balance. The current one is computed, never stored.
  final Money initialBalance;

  final bool isArchived;

  /// UTC; [create] normalises.
  final DateTime createdAt;

  /// UTC. Moved only by the repository, through [stampedAt].
  final DateTime updatedAt;

  /// Optimistic-concurrency token. The server's number: the client never increments it.
  final int version;

  /// Also how the mapper reads a row, so a stricter rule here makes existing rows unreadable.
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
        createdAt: createdAt.toUtc(),
        updatedAt: updatedAt.toUtc(),
        version: version,
      ),
    );
  }

  /// Keeps the old [updatedAt]: the repository restamps it with [stampedAt]. Pass [version] only with a number the server returned.
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

  /// No name or balance: entities end up in logs (golden rule 9).
  @override
  String toString() => 'AccountEntity(id: $id, type: ${type.name}, isArchived: $isArchived, version: $version)';
}
