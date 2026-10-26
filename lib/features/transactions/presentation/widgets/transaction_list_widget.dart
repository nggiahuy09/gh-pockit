import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/localization/localization_scope.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/entities/transaction_entity.dart';
import '../transaction_entity_extension.dart';

/// Stays pinned while its day is on screen, so the rows under it always say which day they belong to.
final class TransactionDayHeaderWidget extends StatelessWidget {
  const TransactionDayHeaderWidget({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final style = context.text.titleSmall.copyWith(color: context.colors.onSurfaceVariant);
    final spacing = context.spacing;
    // A persistent header needs its extent up front; it grows with the system text size like the text inside it.
    final lineHeight = MediaQuery.textScalerOf(context).scale(style.fontSize!) * style.height!;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _DayHeaderDelegate(style: style, label: label, extent: (lineHeight + spacing.md + spacing.sm).ceilToDouble()),
    );
  }
}

final class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DayHeaderDelegate({required this.style, required this.label, required this.extent});

  final TextStyle style;
  final String label;
  final double extent;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  bool shouldRebuild(_DayHeaderDelegate oldDelegate) => oldDelegate.label != label || oldDelegate.style != style || oldDelegate.extent != extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colors = context.colors;
    final spacing = context.spacing;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: overlapsContent ? Border(bottom: BorderSide(color: colors.outlineVariant)) : null,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(spacing.md, spacing.md, spacing.md, spacing.sm),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Semantics(
            header: true,
            child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}

final class TransactionDayCardWidget extends StatelessWidget {
  const TransactionDayCardWidget({super.key, required this.transactions, this.onOpen, this.onDelete});

  final List<TransactionEntity> transactions;
  final void Function(TransactionEntity transaction)? onOpen;

  /// Swiping a row away, or the screen reader's delete action. Completes true once the row is deleted; false puts a swiped row back.
  final Future<bool> Function(TransactionEntity transaction)? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radii.borderLg;
    final onOpen = this.onOpen;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.surface, borderRadius: radius, boxShadow: context.shadows.small),
        child: ClipRRect(
          borderRadius: radius,
          // Transparent, so the ripple draws above the card's colour rather than under it on the page's Material.
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (var i = 0; i < transactions.length; i++)
                  _DeletableRow(
                    key: ValueKey(transactions[i].id),
                    transaction: transactions[i],
                    onDelete: onDelete,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: i == 0 ? null : Border(top: BorderSide(color: colors.outlineVariant)),
                      ),
                      child: TransactionRowWidget(transaction: transactions[i], onTap: onOpen == null ? null : () => onOpen.call(transactions[i])),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Swipe towards the start to delete. The delete is written before the row goes, so the list's next snapshot is what removes it (ADR-0017).
final class _DeletableRow extends StatelessWidget {
  const _DeletableRow({super.key, required this.transaction, required this.onDelete, required this.child});

  final TransactionEntity transaction;
  final Future<bool> Function(TransactionEntity transaction)? onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onDelete = this.onDelete;
    if (onDelete == null) return child;

    final colors = context.colors;
    final label = context.l10n.transactions.delete;

    return Semantics(
      // Swiping is out of reach of a screen reader.
      customSemanticsActions: {CustomSemanticsAction(label: label): () => onDelete.call(transaction)},
      child: Dismissible(
        key: ValueKey('dismiss-${transaction.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => onDelete.call(transaction),
        background: ColoredBox(
          color: colors.danger,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: context.spacing.lg),
              child: Icon(Icons.delete_outline, color: colors.onDanger, semanticLabel: label),
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Only the title is ever cut short; the amount always shows in full.
final class TransactionRowWidget extends StatelessWidget {
  const TransactionRowWidget({super.key, required this.transaction, this.onTap});

  final TransactionEntity transaction;
  final void Function()? onTap;

  static const minHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final textStyle = context.text.bodyLarge;
    final row = ConstrainedBox(
      // Scales with the system text size, as the design's rows do, so a larger text setting keeps the same breathing room.
      constraints: BoxConstraints(minHeight: MediaQuery.textScalerOf(context).scale(minHeight)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
        child: Row(
          children: [
            if (transaction.type.isTransfer) ...[
              Icon(Icons.swap_horiz, size: 18.0, color: colors.onSurfaceVariant),
              const SizedBox(width: 6.0),
            ],
            Expanded(
              child: Text(
                transaction.getTitle(context.l10n),
                style: textStyle.copyWith(color: colors.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: spacing.smd),
            GPMoneyText(
              style: textStyle.copyWith(fontWeight: FontWeight.w600, color: colors.onSurface),
              amount: transaction.amount,
              tone: transaction.moneyTone,
            ),
          ],
        ),
      ),
    );

    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

final class TransactionListBannerWidget extends StatelessWidget {
  const TransactionListBannerWidget.error({super.key, required this.message}) : _isError = true;

  const TransactionListBannerWidget.notice({super.key, required this.message}) : _isError = false;

  final String message;
  final bool _isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final background = _isError ? colors.danger : colors.surfaceVariant;
    final foreground = _isError ? colors.onDanger : colors.onSurfaceVariant;

    return Semantics(
      liveRegion: true,
      child: Container(
        margin: EdgeInsets.fromLTRB(spacing.md, spacing.xs, spacing.md, 0.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(color: background, borderRadius: context.radii.borderMd),
        child: Row(
          spacing: 10.0,
          children: [
            Icon(_isError ? Icons.error_outline : Icons.info_outline, size: 20.0, color: foreground),
            Expanded(
              child: Text(message, style: context.text.bodyMedium.copyWith(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown while the window may hold more rows; scrolling near it loads them, so there is no button.
final class TransactionListFooterWidget extends StatelessWidget {
  const TransactionListFooterWidget({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: context.spacing.md + context.spacing.xs),
    child: Center(
      child: Semantics(
        label: label,
        child: SizedBox.square(
          dimension: 24.0,
          child: CircularProgressIndicator(strokeWidth: 2.0, color: context.colors.onSurfaceVariant),
        ),
      ),
    ),
  );
}

final class TransactionListSkeletonWidget extends StatelessWidget {
  const TransactionListSkeletonWidget({super.key});

  /// Title and amount bar widths per row: uneven on purpose, so it reads as text rather than a grid.
  static const _days = [
    [(120.0, 72.0), (168.0, 64.0), (96.0, 80.0)],
    [(140.0, 96.0), (184.0, 72.0), (112.0, 64.0)],
    [(200.0, 64.0), (88.0, 72.0)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Semantics(
      container: true,
      label: context.l10n.transactions.loading,
      child: ExcludeSemantics(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final rows in _days) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(spacing.md, spacing.md + spacing.xs, spacing.md, 10.0),
                  child: const _SkeletonBar(height: 12.0, width: 88.0),
                ),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: spacing.md),
                  decoration: BoxDecoration(color: colors.surface, borderRadius: context.radii.borderLg, boxShadow: context.shadows.small),
                  child: Column(
                    children: [
                      for (final (title, amount) in rows)
                        SizedBox(
                          height: TransactionRowWidget.minHeight,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: spacing.md),
                            child: Row(
                              children: [
                                _SkeletonBar(height: 14.0, width: title),
                                const Spacer(),
                                _SkeletonBar(height: 14.0, width: amount),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.height, required this.width});

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: DecoratedBox(
      decoration: BoxDecoration(color: context.colors.surfaceVariant, borderRadius: context.radii.borderSm),
    ),
  );
}
