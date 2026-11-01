import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/utils/calendar_month.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';
import 'package:ghpockit/features/transactions/domain/entities/income_expense_totals.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/usecases/watch_category_breakdown_use_case.dart';
import 'package:ghpockit/features/transactions/domain/usecases/watch_monthly_summary_use_case.dart';

import '../../../../helpers/in_memory_repositories.dart';
import '../../../../helpers/results.dart';

const _september = GPCalendarMonth(2026, 9);

/// Real repositories: what matters is which rows a local month takes in, and that both use cases read the same currency.
void main() {
  late InMemoryRepositories repositories;
  late AccountEntity dong;
  late AccountEntity dollars;

  setUp(() async {
    repositories = InMemoryRepositories();
    dong = okValue(await repositories.accounts.createAccount(initialBalance: Money(0, 'VND'), type: AccountType.cash, name: 'Ví'));
    dollars = okValue(await repositories.accounts.createAccount(initialBalance: Money(0, 'USD'), type: AccountType.bank, name: 'Chase'));
  });

  tearDown(() => repositories.close());

  Future<void> spend(int minorUnits, DateTime at, {AccountEntity? account, String? categoryId, TransactionType type = TransactionType.expense}) async {
    final on = account ?? dong;
    okValue(
      await repositories.transactions.createTransaction(
        amount: Money(minorUnits, on.initialBalance.currencyCode),
        type: type,
        occurredAt: at,
        accountId: on.id,
        categoryId: categoryId,
      ),
    );
  }

  test('the summary takes in the local month, from the first at midnight up to, not including, the next first', () async {
    await spend(1, DateTime(2026, 8, 31, 23, 59));
    await spend(10, DateTime(2026, 9));
    await spend(100, DateTime(2026, 9, 30, 23, 59));
    await spend(1000, DateTime(2026, 10));
    await spend(900000, DateTime(2026, 9, 15), type: TransactionType.income);

    final totals = await WatchMonthlySummaryUseCase(repositories.transactions).execute(const WatchMonthlySummaryInput(_september)).first;

    expect(totals, IncomeExpenseTotals(income: Money(900000, 'VND'), expense: Money(110, 'VND')));
  });

  test('both read VND only, so the breakdown adds up to the summary even with a dollar account (ADR-0021)', () async {
    final food = okValue(await repositories.categories.createCategory(type: CategoryType.expense, name: 'Ăn uống'));
    await spend(45000, DateTime(2026, 9, 15), categoryId: food.id);
    await spend(7000, DateTime(2026, 9, 16));
    await spend(1250, DateTime(2026, 9, 17), account: dollars);

    final totals = await WatchMonthlySummaryUseCase(repositories.transactions).execute(const WatchMonthlySummaryInput(_september)).first;
    final breakdown = await WatchCategoryBreakdownUseCase(repositories.transactions).execute(const WatchCategoryBreakdownInput(_september)).first;

    expect(breakdown.map((row) => (row.category?.id, row.amount)), [(food.id, Money(45000, 'VND')), (null, Money(7000, 'VND'))]);
    expect(breakdown.map((row) => row.amount).reduce((a, b) => a + b), totals.expense);
  });

  test('inputs log the month, nothing else', () {
    expect(const WatchMonthlySummaryInput(_september).toLog(), {'year': 2026, 'month': 9});
    expect(const WatchCategoryBreakdownInput(_september).toLog(), {'year': 2026, 'month': 9});
  });
}
