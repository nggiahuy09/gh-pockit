import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/utils/calendar_month.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/dashboard/presentation/bloc/home_category_breakdown_bloc.dart';
import 'package:ghpockit/features/dashboard/presentation/bloc/home_month_summary_bloc.dart';
import 'package:ghpockit/features/transactions/domain/entities/category_spending.dart';
import 'package:ghpockit/features/transactions/domain/entities/income_expense_totals.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

import '../../../../helpers/fake_transaction_repository.dart';
import '../../../../helpers/in_memory_repositories.dart';
import '../../../../helpers/results.dart';

const _october = GPCalendarMonth(2026, 10);

void main() {
  tearDown(getIt.reset);

  group('HomeMonthSummaryBloc', () {
    test("starts loading, then holds the month's totals, and follows a new transaction", () async {
      final repositories = InMemoryRepositories();
      addTearDown(repositories.close);
      getIt.registerSingleton<TransactionRepository>(repositories.transactions);
      final wallet = okValue(await repositories.accounts.createAccount(initialBalance: Money(0, 'VND'), type: AccountType.cash, name: 'Ví'));

      final bloc = HomeMonthSummaryBloc(_october);
      addTearDown(bloc.close);
      final expectation = expectLater(
        bloc.stream,
        emitsInOrder([
          const HomeMonthSummaryLoadingState(null),
          HomeMonthSummaryLoadedState(IncomeExpenseTotals(income: Money(0, 'VND'), expense: Money(0, 'VND'))),
          HomeMonthSummaryLoadedState(IncomeExpenseTotals(income: Money(0, 'VND'), expense: Money(45000, 'VND'))),
        ]),
      );
      await pumpEventQueue();

      await repositories.transactions.createTransaction(
        amount: Money(45000, 'VND'),
        type: TransactionType.expense,
        occurredAt: DateTime(2026, 10, 15),
        accountId: wallet.id,
      );
      await expectation;
    });

    test('a failure keeps the last totals under it, and the next totals clear it', () async {
      final totals = StreamController<IncomeExpenseTotals>();
      addTearDown(totals.close);
      getIt.registerSingleton<TransactionRepository>(_ScriptedRepository(totals: totals.stream));
      final bloc = HomeMonthSummaryBloc(_october);
      addTearDown(bloc.close);
      final empty = IncomeExpenseTotals(income: Money(0, 'VND'), expense: Money(0, 'VND'));

      totals
        ..add(empty)
        ..addError(const GPDatabaseFailure())
        ..add(empty);

      await expectLater(
        bloc.stream,
        emitsInOrder([
          const HomeMonthSummaryLoadingState(null),
          HomeMonthSummaryLoadedState(empty),
          HomeMonthSummaryLoadErrorState(empty, const GPDatabaseFailure()),
          HomeMonthSummaryLoadedState(empty),
        ]),
      );
    });
  });

  group('HomeCategoryBreakdownBloc', () {
    test('a failure before any breakdown leaves nothing to show but the failure', () async {
      final spending = StreamController<List<CategorySpending>>();
      addTearDown(spending.close);
      getIt.registerSingleton<TransactionRepository>(_ScriptedRepository(spending: spending.stream));
      final bloc = HomeCategoryBreakdownBloc(_october);
      addTearDown(bloc.close);

      spending
        ..addError(const GPDatabaseFailure())
        ..add([CategorySpending(category: null, amount: Money(7000, 'VND'))]);

      await expectLater(
        bloc.stream,
        emitsInOrder([
          const HomeCategoryBreakdownLoadingState(null),
          const HomeCategoryBreakdownLoadErrorState(null, GPDatabaseFailure()),
          HomeCategoryBreakdownLoadedState([CategorySpending(category: null, amount: Money(7000, 'VND'))]),
        ]),
      );
    });

    test('anything but a GPFailure is a bug: rethrown, never shown as a sentence', () async {
      final spending = StreamController<List<CategorySpending>>();
      addTearDown(spending.close);
      getIt.registerSingleton<TransactionRepository>(_ScriptedRepository(spending: spending.stream));
      final uncaught = <Object>[];
      late HomeCategoryBreakdownBloc bloc;

      runZonedGuarded(() => bloc = HomeCategoryBreakdownBloc(_october), (error, _) => uncaught.add(error));
      addTearDown(() => bloc.close());
      spending.addError(StateError('broken invariant'));
      await pumpEventQueue();

      expect(uncaught.single, isA<StateError>());
      expect(bloc.state, isNot(isA<HomeCategoryBreakdownLoadErrorState>()));
    });
  });
}

final class _ScriptedRepository extends FakeTransactionRepository {
  _ScriptedRepository({Stream<List<CategorySpending>>? spending, Stream<IncomeExpenseTotals>? totals}) : _spending = spending, _totals = totals;

  final Stream<List<CategorySpending>>? _spending;
  final Stream<IncomeExpenseTotals>? _totals;

  @override
  Stream<IncomeExpenseTotals> watchIncomeExpenseTotals({required String currencyCode, required DateTime from, required DateTime to}) =>
      _totals ?? super.watchIncomeExpenseTotals(currencyCode: currencyCode, from: from, to: to);

  @override
  Stream<List<CategorySpending>> watchSpendingByCategory({required String currencyCode, required DateTime from, required DateTime to}) =>
      _spending ?? super.watchSpendingByCategory(currencyCode: currencyCode, from: from, to: to);
}
