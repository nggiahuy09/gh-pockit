import 'package:meta/meta.dart';

import '../../../../core/domain/loggable.dart';
import '../../../../core/domain/use_case.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/clock.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../accounts/domain/entities/account_type.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../entities/transaction_query.dart';
import '../entities/transaction_type.dart';
import '../repositories/transaction_repository.dart';

/// Debug builds only. Accounts are matched by name, so seeding twice adds rows but never a second "Cash" account.
final class SeedSampleDataUseCase with GPUseCase<SeedSampleDataInput, int> {
  const SeedSampleDataUseCase(this._accountRepository, this._clock, this._transactionRepository);

  final AccountRepository _accountRepository;
  final GPClock _clock;
  final TransactionRepository _transactionRepository;

  @override
  Future<GPResult<int>> execute(SeedSampleDataInput input) async {
    try {
      if (input.onlyIfEmpty) {
        final existing = await _transactionRepository.watchTransactions(TransactionQuery(limit: 1)).first;
        if (existing.rowCount > 0) return const GPOk(0);
      }

      final existingAccounts = await _accountRepository.watchAccounts().first;
      final resolved = <AccountEntity>[];
      for (final sample in input.accounts) {
        final match = existingAccounts.where((account) => account.name == sample.name).firstOrNull;
        if (match != null) {
          resolved.add(match);
          continue;
        }

        final created = await _accountRepository.createAccount(initialBalance: Money(sample.initialBalance, sample.currencyCode), type: sample.type, name: sample.name);
        switch (created) {
          case GPOk(:final value):
            resolved.add(value);
          case GPErr(:final failure):
            return GPErr(failure);
        }
      }

      final today = _clock.nowUtc().toLocal();
      for (final sample in input.transactions) {
        final account = resolved[sample.account];
        final destination = sample.destination;
        final (hour, minute) = sample.time;
        final result = await _transactionRepository.createTransaction(
          amount: Money(sample.amount, account.initialBalance.currencyCode),
          type: sample.type,
          // Through the constructor, not `subtract`: a DST day is not 24 hours long.
          occurredAt: DateTime(today.year, today.month, today.day - sample.daysAgo, hour, minute).toUtc(),
          accountId: account.id,
          destinationAccountId: destination == null ? null : resolved[destination].id,
          note: sample.note,
        );
        if (result case GPErr(:final failure)) return GPErr(failure);
      }

      return GPOk(input.transactions.length);
    } on GPFailure catch (failure) {
      return GPErr(failure);
    }
  }
}

@immutable
final class SeedSampleDataInput implements GPLoggable {
  const SeedSampleDataInput({required List<SampleAccount> accounts, required List<SampleTransaction> transactions, this.onlyIfEmpty = false})
    : _accounts = accounts,
      _transactions = transactions;

  final List<SampleAccount> _accounts;
  final List<SampleTransaction> _transactions;

  final bool onlyIfEmpty;

  List<SampleAccount> get accounts => List.unmodifiable(_accounts);

  List<SampleTransaction> get transactions => List.unmodifiable(_transactions);

  @override
  Map<String, Object?> toLog() => {'accounts': _accounts.length, 'transactions': _transactions.length, 'only_if_empty': onlyIfEmpty};
}

@immutable
final class SampleAccount {
  const SampleAccount({required this.type, this.currencyCode = 'VND', required this.name, this.initialBalance = 0});

  final AccountType type;
  final String currencyCode;
  final String name;

  /// Minor units.
  final int initialBalance;
}

/// Dated relative to the day it is seeded, so "Today" and "Yesterday" always have rows.
@immutable
final class SampleTransaction {
  const SampleTransaction({required this.type, required this.time, this.note, required this.account, required this.amount, required this.daysAgo, this.destination});

  final TransactionType type;

  /// Local `(hour, minute)`.
  final (int, int) time;

  final String? note;

  /// Index into the seeded account list, as is [destination].
  final int account;

  /// Minor units, in the account's currency.
  final int amount;

  final int daysAgo;
  final int? destination;
}
