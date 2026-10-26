import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../../../../core/money/money.dart';
import 'account_entity.dart';

/// Computed on read, never stored (ADR-0019).
@immutable
final class AccountBalance with Equatable {
  const AccountBalance({required this.account, required this.balance});

  final AccountEntity account;
  final Money balance;

  @override
  List<Object?> get props => [account, balance];

  @override
  String toString() => 'AccountBalance(${account.id})';
}
