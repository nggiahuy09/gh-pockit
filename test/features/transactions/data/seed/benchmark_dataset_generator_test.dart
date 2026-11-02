import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/features/categories/data/seed/default_categories.dart';
import 'package:ghpockit/features/transactions/data/seed/benchmark_dataset_generator.dart';
import 'package:ghpockit/features/transactions/data/seed/benchmark_dataset_size_enum.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

import '../../../../helpers/fake_uuid_generator.dart';

// Local, so the range lands on the same days in every host timezone.
final _now = DateTime(2026, 11, 2, 9, 30);
final Map<DefaultCategory, String> _categoryIds = {for (final category in DefaultCategory.values) category: 'cat-${category.nameKey}'};

void main() {
  for (final size in BenchmarkDatasetSize.values) {
    test('writes exactly ${size.key} rows', () {
      expect(_generate(size: size).transactions, hasLength(size.count));
    });
  }

  test('dates every row in the 24 months up to today, today included', () {
    final days = _generate(size: BenchmarkDatasetSize.k10).transactions.map((transaction) => _localDay(transaction.occurredAt)).toList();

    expect(days.where((day) => !day.isAfter(DateTime(2024, 11, 2))), isEmpty, reason: 'exactly 24 months back is outside the range');
    expect(days.where((day) => day.isAfter(DateTime(2026, 11, 2))), isEmpty, reason: 'nothing after today (ADR-0022)');
    expect(days, contains(DateTime(2026, 11, 2)));
  });

  test('every calendar month in the range has rows, the two partial ones at its ends included', () {
    final months = {for (final transaction in _generate().transactions) (transaction.occurredAt.toLocal().year, transaction.occurredAt.toLocal().month)};

    expect(months, hasLength(25));
  });

  test('the same seed gives the same rows, another seed other rows', () {
    final first = _generate();
    final again = _generate();

    expect(again.transactions, first.transactions);
    expect(again.deletedIds, first.deletedIds);
    expect(_generate(seed: 7).transactions, isNot(first.transactions));
  });

  test('lists the rows oldest first, each stamped with now', () {
    final transactions = _generate().transactions;

    for (var i = 1; i < transactions.length; i++) {
      expect(transactions[i].occurredAt.isBefore(transactions[i - 1].occurredAt), isFalse, reason: 'row $i');
    }
    expect(transactions.where((transaction) => transaction.createdAt != _now.toUtc() || transaction.updatedAt != _now.toUtc()), isEmpty);
  });

  test('opens five accounts, one of them in USD', () {
    final accounts = _generate().accounts;

    expect(accounts, hasLength(5));
    expect(accounts.where((account) => account.initialBalance.currencyCode == 'USD'), hasLength(1));
  });

  test("puts every amount in its account's currency, VND in whole thousands", () {
    final dataset = _generate();
    final currencyOf = {for (final account in dataset.accounts) account.id: account.initialBalance.currencyCode};

    expect(dataset.transactions.where((transaction) => transaction.amount.currencyCode != currencyOf[transaction.accountId]), isEmpty);
    expect(dataset.transactions.where((transaction) => transaction.amount.currencyCode == 'VND' && transaction.amount.minorUnits % 1000 != 0), isEmpty);
    expect(dataset.transactions.where((transaction) => transaction.amount.currencyCode == 'USD'), isNotEmpty);
  });

  test('moves a transfer between two accounts, with no category', () {
    final transfers = _generate().transactions.where((transaction) => transaction.type.isTransfer).toList();

    expect(transfers, isNotEmpty);
    expect(
      transfers.where(
        (transfer) => transfer.destinationAccountId == null || transfer.destinationAccountId == transfer.accountId || transfer.categoryId != null,
      ),
      isEmpty,
    );
  });

  test('files an income or an expense under a category of its own kind, or under none', () {
    final kindOf = {for (final entry in _categoryIds.entries) entry.value: entry.key.type};
    final transactions = _generate().transactions;

    expect(transactions.where((transaction) => transaction.categoryId != null && kindOf[transaction.categoryId] != transaction.type.categoryType), isEmpty);
    expect(transactions.where((transaction) => transaction.type == TransactionType.income), isNotEmpty);
  });

  test('leaves about one expense in twenty uncategorised', () {
    final expenses = _generate(size: BenchmarkDatasetSize.k10).transactions.where((transaction) => transaction.type == TransactionType.expense).toList();

    expect(expenses.where((expense) => expense.categoryId == null).length / expenses.length, inInclusiveRange(0.03, 0.08));
  });

  test('pays the salary on the 5th of every month in the range', () {
    final salaries = _generate().transactions.where((transaction) => transaction.categoryId == _categoryIds[DefaultCategory.salary]).toList();

    expect(salaries, hasLength(24), reason: 'November 2024 to October 2026; the 5th of November 2026 is still to come');
    expect(salaries.where((salary) => salary.occurredAt.toLocal().day != 5), isEmpty);
  });

  test('marks about one row in fifty as a tombstone, each one a row of its own', () {
    final dataset = _generate(size: BenchmarkDatasetSize.k10);
    final ids = {for (final transaction in dataset.transactions) transaction.id};

    expect(ids.containsAll(dataset.deletedIds), isTrue);
    expect(dataset.deletedIds.length / ids.length, inInclusiveRange(0.01, 0.03));
  });

  test('puts more rows on a weekend day than on a weekday', () {
    final perDay = <DateTime, int>{};
    for (final transaction in _generate(size: BenchmarkDatasetSize.k10).transactions) {
      perDay.update(_localDay(transaction.occurredAt), (count) => count + 1, ifAbsent: () => 1);
    }
    final weekend = [
      for (final entry in perDay.entries)
        if (entry.key.weekday >= DateTime.saturday) entry.value,
    ];
    final weekday = [
      for (final entry in perDay.entries)
        if (entry.key.weekday < DateTime.saturday) entry.value,
    ];

    expect(_mean(weekend), greaterThan(_mean(weekday) * 1.15));
  });

  test('leaves the rows of a category missing from the map uncategorised, rather than failing', () {
    final dataset = _generate(categoryIds: {..._categoryIds}..remove(DefaultCategory.food));

    expect(dataset.transactions, hasLength(BenchmarkDatasetSize.k1.count));
    expect(dataset.transactions.where((transaction) => transaction.categoryId == _categoryIds[DefaultCategory.food]), isEmpty);
  });
}

BenchmarkDataset _generate({Map<DefaultCategory, String>? categoryIds, BenchmarkDatasetSize size = BenchmarkDatasetSize.k1, int seed = BenchmarkDatasetGenerator.defaultSeed}) =>
    BenchmarkDatasetGenerator(uuidGenerator: FakeUuidGenerator(), seed: seed).generate(categoryIds: categoryIds ?? _categoryIds, size: size, now: _now);

DateTime _localDay(DateTime instant) {
  final local = instant.toLocal();

  return DateTime(local.year, local.month, local.day);
}

double _mean(List<int> values) => values.reduce((a, b) => a + b) / values.length;
