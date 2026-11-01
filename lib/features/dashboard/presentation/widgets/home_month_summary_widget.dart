import 'package:flutter/material.dart';

import '../../../../core/error/failure_extension.dart';
import '../../../../core/localization/localization_scope.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../core/utils/calendar_month.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../transactions/domain/entities/income_expense_totals.dart';
import '../bloc/home_month_summary_bloc.dart';
import 'home_section_message_widget.dart';

/// The month card of the canvas's Home: income minus spending, then each on its own tile.
final class HomeMonthSummaryWidget extends StatelessWidget {
  const HomeMonthSummaryWidget({super.key, required this.month, required this.state});

  final GPCalendarMonth month;
  final HomeMonthSummaryState state;

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;
    final totals = state.totals;

    if (totals != null) return _MonthCard(month: month, totals: totals);

    return switch (state) {
      HomeMonthSummaryLoadErrorState(:final failure) => HomeSectionMessageWidget(
        icon: Icons.error_outline,
        message: locale.home.sectionErrorBody,
        title: failure.getMessage(locale),
      ),
      HomeMonthSummaryInitState() || HomeMonthSummaryLoadingState() || HomeMonthSummaryLoadedState() => const _MonthCardSkeleton(),
    };
  }
}

final class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.month, required this.totals});

  final GPCalendarMonth month;
  final IncomeExpenseTotals totals;

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;
    final colors = context.colors;
    final spacing = context.spacing;
    final text = context.text;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface, borderRadius: context.radii.borderLg, boxShadow: context.shadows.small),
      child: Padding(
        padding: EdgeInsets.fromLTRB(spacing.md + spacing.xs, spacing.md + spacing.xs, spacing.md + spacing.xs, spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.md,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      locale.widgets.datePicker.monthYear(month: month.month, year: month.year),
                      style: text.titleSmall.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                ),
                Icon(Icons.calendar_month_outlined, size: 20.0, color: colors.onSurfaceVariant),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: spacing.xs,
              children: [
                Text(locale.home.netThisMonth, style: text.bodySmall.copyWith(color: colors.onSurfaceVariant)),
                _ShrinkToFit(
                  child: GPMoneyText(
                    style: text.displayMedium.copyWith(color: colors.onSurface),
                    amount: totals.net,
                  ),
                ),
              ],
            ),
            // One height for both tiles, even when one amount had to shrink.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing.smd,
                children: [
                  Expanded(
                    child: _Tile(amount: totals.income, icon: Icons.south_west, label: locale.transactions.typeIncome, tone: GPMoneyTone.income),
                  ),
                  Expanded(
                    child: _Tile(amount: totals.expense, icon: Icons.north_east, label: locale.transactions.typeExpense, tone: GPMoneyTone.expense),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Tile extends StatelessWidget {
  const _Tile({required this.amount, required this.icon, required this.label, required this.tone});

  final Money amount;
  final IconData icon;
  final String label;
  final GPMoneyTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: context.radii.borderMd),
      child: Padding(
        padding: EdgeInsets.all(spacing.smd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: spacing.xs,
          children: [
            Row(
              spacing: spacing.xs,
              children: [
                Icon(icon, size: 16.0, color: colors.onSurfaceVariant),
                Flexible(
                  child: Text(label, style: context.text.bodySmall.copyWith(color: colors.onSurfaceVariant)),
                ),
              ],
            ),
            // A signed zero reads as money that moved, so a month with nothing in it shows a plain 0.
            _ShrinkToFit(
              child: GPMoneyText(
                style: context.text.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                amount: amount,
                tone: amount.isZero ? GPMoneyTone.neutral : tone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `GPMoneyText` never cuts an amount, so in a half-width tile a large figure at a large text size would run past the edge: it scales down instead.
final class _ShrinkToFit extends StatelessWidget {
  const _ShrinkToFit({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: child);
}

final class _MonthCardSkeleton extends StatelessWidget {
  const _MonthCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    Widget bar(double width, double height) => SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: context.radii.borderSm),
      ),
    );

    return Semantics(
      container: true,
      label: context.l10n.home.loadingMonth,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.surface, borderRadius: context.radii.borderLg, boxShadow: context.shadows.small),
          child: Padding(
            padding: EdgeInsets.fromLTRB(spacing.md + spacing.xs, spacing.md + spacing.xs, spacing.md + spacing.xs, spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: spacing.md,
              children: [
                bar(112.0, 14.0),
                Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: spacing.sm, children: [bar(120.0, 12.0), bar(200.0, 32.0)]),
                Row(
                  spacing: spacing.smd,
                  children: [
                    Expanded(child: bar(double.infinity, 66.0)),
                    Expanded(child: bar(double.infinity, 66.0)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
