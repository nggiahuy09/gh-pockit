import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:meta/meta.dart';

@immutable
final class SampleAccount {
  const SampleAccount(this.name, this.type, {this.currencyCode = 'VND', this.initialBalance = 0});

  final String name;
  final AccountType type;
  final String currencyCode;

  /// Minor units.
  final int initialBalance;
}

/// Dated relative to the day it is seeded, so "Today" and "Yesterday" always have rows.
@immutable
final class SampleTransaction {
  const SampleTransaction({
    required this.daysAgo,
    required this.time,
    required this.type,
    required this.amount,
    required this.account,
    this.destination,
    this.note,
  });

  final int daysAgo;

  /// Local `(hour, minute)`.
  final (int, int) time;
  final TransactionType type;

  /// Minor units, in the account's currency.
  final int amount;

  /// Index into the seeded account list.
  final int account;
  final int? destination;
  final String? note;
}

/// Debug builds only: writes a whole dataset through the repositories, so the list is fed by the real query.
class SeedSampleDataUseCase {
  const SeedSampleDataUseCase({required AccountRepository accountRepository, required TransactionRepository transactionRepository, required GPClock clock})
    : _accounts = accountRepository,
      _transactions = transactionRepository,
      _clock = clock;

  final AccountRepository _accounts;
  final TransactionRepository _transactions;
  final GPClock _clock;

  /// Returns how many transactions it wrote. Accounts are matched by name, so seeding twice adds rows but never a second "Cash" account.
  /// With [onlyIfEmpty], a database that already holds a transaction is left alone.
  Future<GPResult<int>> call({required List<SampleAccount> accounts, required List<SampleTransaction> transactions, bool onlyIfEmpty = false}) async {
    try {
      if (onlyIfEmpty) {
        final existing = await _transactions.watchTransactions(TransactionQuery(limit: 1)).first;
        if (existing.rowCount > 0) return const GPOk<int>(0);
      }

      final existingAccounts = await _accounts.watchAccounts().first;
      final resolved = <AccountEntity>[];
      for (final sample in accounts) {
        final match = existingAccounts.where((AccountEntity a) => a.name == sample.name).firstOrNull;
        if (match != null) {
          resolved.add(match);
          continue;
        }

        final created = await _accounts.createAccount(name: sample.name, type: sample.type, initialBalance: Money(sample.initialBalance, sample.currencyCode));
        switch (created) {
          case GPOk<AccountEntity>(:final value):
            resolved.add(value);
          case GPErr<AccountEntity>(:final failure):
            return GPErr<int>(failure);
        }
      }

      final today = _clock.nowUtc().toLocal();
      for (final sample in transactions) {
        final account = resolved[sample.account];
        final (hour, minute) = sample.time;
        final result = await _transactions.createTransaction(
          type: sample.type,
          accountId: account.id,
          destinationAccountId: sample.destination == null ? null : resolved[sample.destination!].id,
          amount: Money(sample.amount, account.initialBalance.currencyCode),
          // Through the constructor, not `subtract`: a DST day is not 24 hours long.
          occurredAt: DateTime(today.year, today.month, today.day - sample.daysAgo, hour, minute).toUtc(),
          note: sample.note,
        );
        if (result case GPErr<TransactionEntity>(:final failure)) return GPErr<int>(failure);
      }

      return GPOk<int>(transactions.length);
    } on GPFailure catch (failure) {
      return GPErr<int>(failure);
    }
  }
}
