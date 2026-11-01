import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/utils/calendar_month.dart';
import 'package:ghpockit/features/dashboard/presentation/bloc/home_category_breakdown_bloc.dart';
import 'package:ghpockit/features/dashboard/presentation/bloc/home_month_summary_bloc.dart';
import 'package:ghpockit/features/dashboard/presentation/widgets/home_category_breakdown_widget.dart';
import 'package:ghpockit/features/dashboard/presentation/widgets/home_month_summary_widget.dart';
import 'package:ghpockit/features/transactions/domain/entities/category_spending.dart';
import 'package:ghpockit/features/transactions/domain/entities/income_expense_totals.dart';

import '../../../../helpers/localization_harness.dart';
import '../../../../helpers/widget_harness.dart';

/// Both found on the simulator at W8 T4, where the fonts and text sizes differ from the test defaults.
void main() {
  testWidgets('at a large text size, a big amount shrinks into its tile instead of running into the next one', (tester) async {
    final totals = IncomeExpenseTotals(income: Money(18850000, 'VND'), expense: Money(337000, 'VND'));
    await pumpOnPhone(
      tester,
      localization: await localizationFor(GPLocale.vi),
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
          child: HomeMonthSummaryWidget(month: const GPCalendarMonth(2026, 11), state: HomeMonthSummaryLoadedState(totals)),
        ),
      ),
    );

    // `textContaining`: the formatter puts a no-break space before the symbol.
    expect(tester.getRect(find.textContaining('+18.850.000')).right, lessThan(tester.getRect(find.textContaining('-337.000')).left));
  });

  testWidgets('"100%" stays on one line', (tester) async {
    await pumpOnPhone(
      tester,
      localization: await localizationFor(GPLocale.vi),
      child: HomeCategoryBreakdownWidget(state: HomeCategoryBreakdownLoadedState([CategorySpending(category: null, amount: Money(282000, 'VND'))])),
    );

    final style = DefaultTextStyle.of(tester.element(find.text('100%'))).style;
    expect(tester.getSize(find.text('100%')).height, lessThan(2 * (style.fontSize ?? 14.0)));
  });
}
