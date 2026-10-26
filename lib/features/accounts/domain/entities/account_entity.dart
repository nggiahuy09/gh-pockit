import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/money/money.dart';
import 'account_type.dart';

@immutable
final class AccountEntity with Equatable {
  const AccountEntity._({
    required this.initialBalance,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    required this.id,
    required this.name,
    required this.version,
    required this.isArchived,
  });

  /// Also how the mapper reads a row, so a stricter rule here makes existing rows unreadable.
  static GPResult<AccountEntity> create({
    required Money initialBalance,
    required AccountType type,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String id,
    required String name,
    int version = 1,
    bool isArchived = false,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return const GPErr(GPValidationFailure(GPValidationCode.accountNameEmpty));
    if (trimmedName.length > nameMaxLength) return const GPErr(GPValidationFailure(GPValidationCode.accountNameTooLong));

    return GPOk(
      AccountEntity._(
        initialBalance: initialBalance,
        type: type,
        createdAt: createdAt.toUtc(),
        updatedAt: updatedAt.toUtc(),
        id: id,
        name: trimmedName,
        version: version,
        isArchived: isArchived,
      ),
    );
  }

  final Money initialBalance;
  final AccountType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String id;
  final String name;

  /// The server's optimistic-concurrency token: the client never increments it.
  final int version;

  final bool isArchived;

  static const nameMaxLength = 100;

  @override
  List<Object?> get props => [initialBalance, type, createdAt, updatedAt, id, name, version, isArchived];

  /// Keeps [updatedAt]: the repository restamps it. The currency is fixed at creation (ADR-0010), so the balance comes in as minor units.
  GPResult<AccountEntity> update({AccountType? type, String? name, int? initialBalanceMinorUnits, int? version, bool? isArchived}) => create(
    initialBalance: initialBalanceMinorUnits == null ? initialBalance : Money(initialBalanceMinorUnits, initialBalance.currencyCode),
    type: type ?? this.type,
    createdAt: createdAt,
    updatedAt: updatedAt,
    id: id,
    name: name ?? this.name,
    version: version ?? this.version,
    isArchived: isArchived ?? this.isArchived,
  );

  AccountEntity withUpdatedAt(DateTime updatedAt) => AccountEntity._(
    initialBalance: initialBalance,
    type: type,
    createdAt: createdAt,
    updatedAt: updatedAt.toUtc(),
    id: id,
    name: name,
    version: version,
    isArchived: isArchived,
  );

  /// No name or balance: entities end up in logs (golden rule 9).
  @override
  String toString() => 'AccountEntity(id: $id, type: ${type.name}, isArchived: $isArchived, version: $version)';
}
