import 'dart:math';

import 'package:meta/meta.dart';

import '../../../../core/error/result.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/uuid_generator.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../accounts/domain/entities/account_type.dart';
import '../../../categories/data/seed/default_categories.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transaction_type.dart';
import 'benchmark_dataset_size_enum.dart';

/// Same seed and same day, same rows, ids aside. Always the [months] up to today, so the density grows with the size (ADR-0025).
final class BenchmarkDatasetGenerator {
  const BenchmarkDatasetGenerator({required GPUuidGenerator uuidGenerator, int seed = defaultSeed}) : _uuidGenerator = uuidGenerator, _seed = seed;

  final GPUuidGenerator _uuidGenerator;
  final int _seed;

  static const defaultSeed = 42;
  static const months = 24;

  static const _notePercent = 40;

  // A weekend day gets 30% more rows than a weekday.
  static const _weekdayWeight = 10;
  static const _weekendWeight = 13;

  // One row in fifty is a tombstone, so a read that forgets `deleted_at IS NULL` shows in the numbers.
  static const _tombstoneOneIn = 50;

  /// [categoryIds] maps the seeded categories to their ids; a missing one leaves its rows uncategorised. [now] stamps every row and, read in local
  /// time, is the last day: nothing is dated after today (ADR-0022).
  BenchmarkDataset generate({required Map<DefaultCategory, String> categoryIds, required BenchmarkDatasetSize size, required DateTime now}) {
    final random = Random(_seed);
    final today = now.toLocal();
    final firstDay = DateTime(today.year, today.month - months, today.day + 1);
    final endExclusive = DateTime(today.year, today.month, today.day + 1);

    final drafts = _monthlyDrafts(random, endExclusive: endExclusive, firstDay: firstDay);
    drafts
      ..addAll(_dailyDrafts(random, endExclusive: endExclusive, firstDay: firstDay, count: size.count - drafts.length))
      // Ids are minted in date order, as a user's would be, so the id and rowid orders follow `occurred_at`.
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    final accounts = [
      for (final account in _Account.values)
        _valueOf(
          AccountEntity.create(
            initialBalance: Money(account.initialBalance, account.currencyCode),
            type: account.type,
            createdAt: now,
            updatedAt: now,
            id: _uuidGenerator.v7(),
            name: account.label,
          ),
        ),
    ];
    final transactions = [
      for (final draft in drafts)
        _valueOf(
          TransactionEntity.create(
            amount: Money(draft.amount, draft.account.currencyCode),
            type: draft.type,
            createdAt: now,
            occurredAt: draft.occurredAt,
            updatedAt: now,
            accountId: accounts[draft.account.index].id,
            categoryId: categoryIds[draft.category],
            destinationAccountId: switch (draft.destination) {
              final _Account destination => accounts[destination.index].id,
              null => null,
            },
            id: _uuidGenerator.v7(),
            note: draft.note,
          ),
        ),
    ];

    return BenchmarkDataset(
      accounts: accounts,
      deletedIds: {
        for (final transaction in transactions)
          if (random.nextInt(_tombstoneOneIn) == 0) transaction.id,
      },
      transactions: transactions,
    );
  }

  List<_Draft> _monthlyDrafts(Random random, {required DateTime endExclusive, required DateTime firstDay}) {
    final drafts = <_Draft>[];
    for (var offset = 0; offset <= months; offset++) {
      for (final event in _Monthly.values) {
        final occurredAt = DateTime(firstDay.year, firstDay.month + offset, event.day, event.hour, random.nextInt(60));
        final amount = _amount(random, max: event.maxAmount, min: event.minAmount, step: event.account.amountStep);
        if (occurredAt.isBefore(firstDay) || !occurredAt.isBefore(endExclusive)) continue;

        drafts.add((
          account: event.account,
          category: event.category,
          destination: event.destination,
          type: event.type,
          occurredAt: occurredAt,
          note: event.note,
          amount: amount,
        ));
      }
    }

    return drafts;
  }

  List<_Draft> _dailyDrafts(Random random, {required DateTime endExclusive, required DateTime firstDay, required int count}) {
    final days = <DateTime>[];
    for (var day = firstDay; day.isBefore(endExclusive); day = DateTime(day.year, day.month, day.day + 1)) {
      days.add(day);
    }
    final dayWeights = _cumulative([for (final day in days) day.weekday >= DateTime.saturday ? _weekendWeight : _weekdayWeight]);
    final kindWeights = _cumulative([for (final kind in _Daily.values) kind.weight]);

    return [for (var i = 0; i < count; i++) _dailyDraft(random, kind: _Daily.values[_indexAt(random, kindWeights)], day: days[_indexAt(random, dayWeights)])];
  }

  _Draft _dailyDraft(Random random, {required _Daily kind, required DateTime day}) {
    final account = kind.accounts[random.nextInt(kind.accounts.length)];
    final hasNote = kind.notes.isNotEmpty && random.nextInt(100) < _notePercent;

    return (
      account: account,
      category: kind.category,
      destination: kind.destination,
      type: kind.type,
      occurredAt: DateTime(day.year, day.month, day.day, kind.fromHour + random.nextInt(kind.toHour - kind.fromHour), random.nextInt(60)),
      note: hasNote ? kind.notes[random.nextInt(kind.notes.length)] : null,
      amount: _amount(random, max: kind.maxAmount, min: kind.minAmount, step: account.amountStep),
    );
  }

  List<int> _cumulative(List<int> weights) {
    var total = 0;

    return [for (final weight in weights) total += weight];
  }

  /// The first index whose running total passes a draw below the last total, so each index is picked in proportion to its weight.
  int _indexAt(Random random, List<int> cumulative) {
    final target = random.nextInt(cumulative.last);
    var low = 0;
    var high = cumulative.length - 1;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (cumulative[middle] > target) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }

    return low;
  }

  int _amount(Random random, {required int max, required int min, required int step}) => (min + random.nextInt(max - min + 1)) ~/ step * step;

  /// The tables below are valid by construction: a refusal is a bug in them, not data.
  T _valueOf<T>(GPResult<T> result) => switch (result) {
    GPOk(:final value) => value,
    GPErr(:final failure) => throw StateError('benchmark row broke a domain rule: $failure'),
  };
}

@immutable
final class BenchmarkDataset {
  const BenchmarkDataset({required List<AccountEntity> accounts, required Set<String> deletedIds, required List<TransactionEntity> transactions})
    : _accounts = accounts,
      _deletedIds = deletedIds,
      _transactions = transactions;

  final List<AccountEntity> _accounts;
  final Set<String> _deletedIds;
  final List<TransactionEntity> _transactions;

  List<AccountEntity> get accounts => List.unmodifiable(_accounts);

  /// The rows to store as tombstones.
  Set<String> get deletedIds => Set.unmodifiable(_deletedIds);

  /// Oldest first.
  List<TransactionEntity> get transactions => List.unmodifiable(_transactions);
}

typedef _Draft = ({_Account account, DefaultCategory? category, _Account? destination, TransactionType type, DateTime occurredAt, String? note, int amount});

enum _Account {
  cash(type: AccountType.cash, label: 'Tiền mặt', initialBalance: 2000000),
  salary(type: AccountType.bank, label: 'Tài khoản lương', initialBalance: 40000000),
  eWallet(type: AccountType.eWallet, label: 'Ví điện tử', initialBalance: 500000),
  creditCard(type: AccountType.creditCard, label: 'Thẻ tín dụng', initialBalance: 0),
  usd(type: AccountType.bank, currencyCode: 'USD', label: 'Chase', initialBalance: 100000);

  const _Account({required this.type, this.currencyCode = 'VND', required this.label, required this.initialBalance});

  final AccountType type;
  final String currencyCode;
  final String label;

  /// Minor units.
  final int initialBalance;

  /// VND is spent in thousands; a USD amount is in cents.
  int get amountStep => currencyCode == 'VND' ? 1000 : 1;
}

/// On a fixed day of every month in the range.
enum _Monthly {
  salary(account: _Account.salary, category: DefaultCategory.salary, type: TransactionType.income, note: 'Lương', day: 5, hour: 9, maxAmount: 26000000, minAmount: 22000000),
  rent(account: _Account.salary, category: DefaultCategory.housing, type: TransactionType.expense, note: 'Tiền nhà', day: 1, hour: 20, maxAmount: 6500000, minAmount: 6500000),
  electricity(account: _Account.salary, category: DefaultCategory.bills, type: TransactionType.expense, note: 'Tiền điện', day: 8, hour: 19, maxAmount: 1200000, minAmount: 400000),
  water(account: _Account.salary, category: DefaultCategory.bills, type: TransactionType.expense, note: 'Tiền nước', day: 10, hour: 19, maxAmount: 200000, minAmount: 80000),
  internet(account: _Account.salary, category: DefaultCategory.bills, type: TransactionType.expense, note: 'Internet', day: 15, hour: 20, maxAmount: 245000, minAmount: 245000),
  phone(
    account: _Account.eWallet,
    category: DefaultCategory.bills,
    type: TransactionType.expense,
    note: 'Cước điện thoại',
    day: 18,
    hour: 21,
    maxAmount: 200000,
    minAmount: 100000,
  ),
  walletTopUp(account: _Account.salary, destination: _Account.eWallet, type: TransactionType.transfer, note: 'Nạp ví', day: 6, hour: 12, maxAmount: 4000000, minAmount: 2000000),
  cashWithdrawal(
    account: _Account.salary,
    destination: _Account.cash,
    type: TransactionType.transfer,
    note: 'Rút tiền mặt',
    day: 7,
    hour: 18,
    maxAmount: 5000000,
    minAmount: 2000000,
  ),
  cardPayment(
    account: _Account.salary,
    destination: _Account.creditCard,
    type: TransactionType.transfer,
    note: 'Trả thẻ tín dụng',
    day: 25,
    hour: 10,
    maxAmount: 8000000,
    minAmount: 3000000,
  );

  const _Monthly({
    required this.account,
    this.category,
    this.destination,
    required this.type,
    required this.note,
    required this.day,
    required this.hour,
    required this.maxAmount,
    required this.minAmount,
  });

  final _Account account;
  final DefaultCategory? category;
  final _Account? destination;
  final TransactionType type;
  final String note;
  final int day;
  final int hour;
  final int maxAmount;
  final int minAmount;
}

/// Spread over the days by [weight], at an hour in `[fromHour, toHour)`.
enum _Daily {
  coffee(
    accounts: [_Account.cash, _Account.eWallet],
    notes: ['Cà phê', 'Cà phê sáng', 'Trà sữa'],
    category: DefaultCategory.food,
    fromHour: 7,
    maxAmount: 65000,
    minAmount: 25000,
    toHour: 17,
    weight: 14,
  ),
  breakfast(
    accounts: [_Account.cash],
    notes: ['Bánh mì', 'Phở', 'Xôi'],
    category: DefaultCategory.food,
    fromHour: 6,
    maxAmount: 50000,
    minAmount: 20000,
    toHour: 9,
    weight: 10,
  ),
  lunch(
    accounts: [_Account.cash, _Account.eWallet],
    notes: ['Ăn trưa', 'Cơm văn phòng', 'Bún chả'],
    category: DefaultCategory.food,
    fromHour: 11,
    maxAmount: 90000,
    minAmount: 35000,
    toHour: 14,
    weight: 16,
  ),
  dinner(
    accounts: [_Account.eWallet, _Account.creditCard, _Account.cash],
    notes: ['Ăn tối', 'Lẩu với bạn', 'Đặt đồ ăn'],
    category: DefaultCategory.food,
    fromHour: 18,
    maxAmount: 400000,
    minAmount: 60000,
    toHour: 22,
    weight: 10,
  ),
  groceries(
    accounts: [_Account.creditCard, _Account.eWallet],
    notes: ['Siêu thị', 'Đi chợ'],
    category: DefaultCategory.food,
    fromHour: 8,
    maxAmount: 1200000,
    minAmount: 150000,
    toHour: 21,
    weight: 6,
  ),
  ride(
    accounts: [_Account.eWallet],
    notes: ['Grab', 'Xe ôm'],
    category: DefaultCategory.transport,
    fromHour: 7,
    maxAmount: 120000,
    minAmount: 20000,
    toHour: 23,
    weight: 10,
  ),
  fuel(accounts: [_Account.cash], notes: ['Đổ xăng'], category: DefaultCategory.transport, fromHour: 7, maxAmount: 120000, minAmount: 50000, toHour: 20, weight: 4),
  shopping(
    accounts: [_Account.creditCard, _Account.eWallet],
    notes: ['Shopee', 'Quần áo', 'Đồ gia dụng'],
    category: DefaultCategory.shopping,
    fromHour: 10,
    maxAmount: 2000000,
    minAmount: 100000,
    toHour: 23,
    weight: 7,
  ),
  entertainment(
    accounts: [_Account.creditCard, _Account.eWallet],
    notes: ['Xem phim', 'Karaoke'],
    category: DefaultCategory.entertainment,
    fromHour: 18,
    maxAmount: 500000,
    minAmount: 80000,
    toHour: 23,
    weight: 5,
  ),
  health(
    accounts: [_Account.cash, _Account.salary],
    notes: ['Thuốc', 'Khám bệnh'],
    category: DefaultCategory.health,
    fromHour: 8,
    maxAmount: 800000,
    minAmount: 50000,
    toHour: 20,
    weight: 3,
  ),
  education(
    accounts: [_Account.salary, _Account.creditCard],
    notes: ['Sách', 'Khoá học online'],
    category: DefaultCategory.education,
    fromHour: 9,
    maxAmount: 2000000,
    minAmount: 100000,
    toHour: 22,
    weight: 2,
  ),
  other(
    accounts: [_Account.cash, _Account.eWallet],
    notes: ['Quà sinh nhật', 'Từ thiện'],
    category: DefaultCategory.otherExpense,
    fromHour: 8,
    maxAmount: 500000,
    minAmount: 20000,
    toHour: 22,
    weight: 4,
  ),
  uncategorised(accounts: [_Account.cash, _Account.eWallet], notes: [], fromHour: 7, maxAmount: 300000, minAmount: 10000, toHour: 22, weight: 5),
  subscription(
    accounts: [_Account.usd],
    notes: ['Spotify', 'iCloud', 'Netflix'],
    category: DefaultCategory.entertainment,
    fromHour: 0,
    maxAmount: 1999,
    minAmount: 99,
    toHour: 24,
    weight: 1,
  ),
  sideIncome(
    accounts: [_Account.eWallet, _Account.salary],
    notes: ['Bán đồ cũ', 'Freelance'],
    category: DefaultCategory.otherIncome,
    type: TransactionType.income,
    fromHour: 9,
    maxAmount: 3000000,
    minAmount: 200000,
    toHour: 22,
    weight: 1,
  ),
  walletTopUp(
    accounts: [_Account.salary],
    notes: ['Nạp ví'],
    destination: _Account.eWallet,
    type: TransactionType.transfer,
    fromHour: 8,
    maxAmount: 2000000,
    minAmount: 300000,
    toHour: 22,
    weight: 1,
  ),
  cashWithdrawal(
    accounts: [_Account.salary],
    notes: ['Rút tiền mặt'],
    destination: _Account.cash,
    type: TransactionType.transfer,
    fromHour: 8,
    maxAmount: 3000000,
    minAmount: 500000,
    toHour: 22,
    weight: 1,
  );

  const _Daily({
    required this.accounts,
    required this.notes,
    this.category,
    this.destination,
    this.type = TransactionType.expense,
    required this.fromHour,
    required this.maxAmount,
    required this.minAmount,
    required this.toHour,
    required this.weight,
  });

  final List<_Account> accounts;
  final List<String> notes;
  final DefaultCategory? category;
  final _Account? destination;
  final TransactionType type;
  final int fromHour;
  final int maxAmount;
  final int minAmount;
  final int toHour;
  final int weight;
}
