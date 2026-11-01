import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/calendar_month.dart';
import '../../../../core/utils/clock.dart';
import '../bloc/home_accounts_bloc.dart';
import '../bloc/home_category_breakdown_bloc.dart';
import '../bloc/home_month_summary_bloc.dart';
import 'home_view.dart';

final class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.clock});

  final GPClock clock;

  @override
  Widget build(BuildContext context) {
    // One month for both sections, so their figures can never be about two different months.
    final month = GPCalendarMonth.of(clock.nowUtc().toLocal());

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => HomeAccountsBloc()),
        BlocProvider(create: (_) => HomeMonthSummaryBloc(month)),
        BlocProvider(create: (_) => HomeCategoryBreakdownBloc(month)),
      ],
      child: const HomeView(),
    );
  }
}
