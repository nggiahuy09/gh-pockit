import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:meta/meta.dart';

/// An account with what it holds now: the opening balance plus every live transaction on either side (ADR-0009). Computed on read, never stored
/// (ADR-0019), so nothing writes it and it has no identity of its own.
@immutable
final class AccountBalance {
  const AccountBalance({required this.account, required this.balance});

  final AccountEntity account;

  /// In the account's currency; below zero for a card or a loan that is owed.
  final Money balance;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AccountBalance && other.account == account && other.balance == balance;

  @override
  int get hashCode => Object.hash(account, balance);

  @override
  String toString() => 'AccountBalance(${account.id})';
}
