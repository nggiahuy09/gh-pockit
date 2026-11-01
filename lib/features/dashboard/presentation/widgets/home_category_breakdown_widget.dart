import 'package:flutter/material.dart';

import '../../../../core/error/failure_extension.dart';
import '../../../../core/localization/localization_scope.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../categories/presentation/category_entity_extension.dart';
import '../../../categories/presentation/widgets/category_icon_widget.dart';
import '../../../transactions/domain/entities/category_spending.dart';
import '../bloc/home_category_breakdown_bloc.dart';
import '../home_category_rows.dart';
import 'home_section_message_widget.dart';

/// Option A of the W8 canvas: ranked horizontal bars in one ink, the amount always printed beside them, so colour never carries the figure.
final class HomeCategoryBreakdownWidget extends StatelessWidget {
  const HomeCategoryBreakdownWidget({super.key, required this.state});

  final HomeCategoryBreakdownState state;

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;
    final breakdown = state.breakdown;

    final Widget body;
    if (breakdown != null) {
      final rows = HomeCategoryRows.of(breakdown);
      body = rows.isEmpty
          ? HomeSectionMessageWidget(icon: Icons.receipt_long_outlined, message: locale.home.noSpendingBody, title: locale.home.noSpendingTitle)
          : _BreakdownCard(rows: rows);
    } else {
      body = switch (state) {
        HomeCategoryBreakdownLoadErrorState(:final failure) => HomeSectionMessageWidget(
          icon: Icons.error_outline,
          message: locale.home.sectionErrorBody,
          title: failure.getMessage(locale),
        ),
        HomeCategoryBreakdownInitState() || HomeCategoryBreakdownLoadingState() || HomeCategoryBreakdownLoadedState() => const _BreakdownSkeleton(),
      };
    }

    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.sm,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.xs),
          child: Semantics(
            header: true,
            child: Text(locale.home.spendingByCategory, style: context.text.headlineSmall.copyWith(color: context.colors.onBackground)),
          ),
        ),
        body,
      ],
    );
  }
}

final class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.rows});

  final HomeCategoryRows rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final rest = rows.rest;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface, borderRadius: context.radii.borderLg, boxShadow: context.shadows.small),
      child: Column(
        children: [
          for (var i = 0; i < rows.rows.length; i++) ...[
            if (i > 0) Divider(height: 1.0, thickness: 1.0, color: colors.outlineVariant),
            _BreakdownRow(rows: rows, spending: rows.rows[i]),
          ],
          if (rest != null) ...[
            Divider(height: 1.0, thickness: 1.0, color: colors.outlineVariant),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.smd),
              child: Row(
                children: [
                  Expanded(
                    child: Text(context.l10n.home.otherCategories(rows.restCount), style: context.text.bodyMedium.copyWith(color: colors.onSurfaceVariant)),
                  ),
                  GPMoneyText(
                    style: context.text.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: colors.onSurfaceVariant),
                    amount: rest,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Not tappable yet: the transactions tab takes no filter from a route.
final class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.rows, required this.spending});

  final HomeCategoryRows rows;
  final CategorySpending spending;

  static const minHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n;
    final colors = context.colors;
    final spacing = context.spacing;
    final category = spending.category;
    final name = category == null ? locale.transactions.uncategorised : category.getTitle(locale);
    final percent = rows.percentOf(spending.amount);
    // "Uncategorised" is muted so it never competes with a real category, wherever its size puts it.
    final ink = category == null ? colors.onSurfaceVariant : colors.onSurface;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: locale.home.categoryShare(amount: GPMoneyFormatter(locale.locale).format(spending.amount), name: name, percent: percent),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.smd),
          child: Row(
            spacing: spacing.smd,
            children: [
              CategoryIconWidget(category: category),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: spacing.sm,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      spacing: spacing.sm,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyLarge.copyWith(color: ink),
                          ),
                        ),
                        GPMoneyText(
                          style: context.text.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: colors.onSurface),
                          amount: spending.amount,
                        ),
                      ],
                    ),
                    Row(
                      spacing: spacing.sm,
                      children: [
                        Expanded(
                          child: _Bar(color: ink, fraction: rows.barOf(spending.amount)),
                        ),
                        // A minimum, not a fixed width, so the bars line up yet "100%" or a larger text size never wraps.
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 40.0),
                          child: Text(
                            '$percent%',
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.end,
                            style: context.text.labelMedium.copyWith(color: colors.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _Bar extends StatelessWidget {
  const _Bar({required this.color, required this.fraction});

  final Color color;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: 6.0,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: context.radii.borderFull,
        border: Border.all(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: fraction.clamp(0.0, 1.0),
        heightFactor: 1.0,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: context.radii.borderFull),
        ),
      ),
    );
  }
}

final class _BreakdownSkeleton extends StatelessWidget {
  const _BreakdownSkeleton();

  /// Name and amount bar widths per row: uneven on purpose, so it reads as text rather than a grid.
  static const _rows = [(120.0, 80.0), (150.0, 96.0), (104.0, 72.0)];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    Widget bar(double width, double height, [BorderRadius? radius]) => SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: radius ?? context.radii.borderSm),
      ),
    );

    return Semantics(
      container: true,
      label: context.l10n.home.loadingSpending,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.surface, borderRadius: context.radii.borderLg, boxShadow: context.shadows.small),
          child: Column(
            children: [
              for (final (name, amount) in _rows)
                SizedBox(
                  height: _BreakdownRow.minHeight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: spacing.md),
                    child: Row(
                      spacing: spacing.smd,
                      children: [
                        bar(CategoryIconWidget.size, CategoryIconWidget.size, context.radii.borderFull),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: spacing.smd,
                            children: [
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [bar(name, 14.0), bar(amount, 14.0)]),
                              bar(double.infinity, 6.0, context.radii.borderFull),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
