import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/widgets/money_text.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/presentation/transaction_labels.dart';

/// Stays pinned while its day is on screen, so the rows under it always say which day they belong to.
class TransactionDayHeader extends StatelessWidget {
  const TransactionDayHeader({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final style = context.text.titleSmall.copyWith(color: context.colors.onSurfaceVariant);
    final spacing = context.spacing;
    // A persistent header needs its extent up front; it grows with the system text size like the text inside it.
    final lineHeight = MediaQuery.textScalerOf(context).scale(style.fontSize!) * style.height!;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _DayHeaderDelegate(label: label, style: style, extent: (lineHeight + spacing.md + spacing.sm).ceilToDouble()),
    );
  }
}

class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DayHeaderDelegate({required this.label, required this.style, required this.extent});

  final String label;
  final TextStyle style;
  final double extent;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

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

  @override
  bool shouldRebuild(_DayHeaderDelegate oldDelegate) => oldDelegate.label != label || oldDelegate.style != style || oldDelegate.extent != extent;
}

/// One day's rows on a single card.
class TransactionDayCard extends StatelessWidget {
  const TransactionDayCard({required this.transactions, this.onOpen, this.onDelete, super.key});

  final List<TransactionEntity> transactions;

  /// Not offered for a transfer, which the form cannot show until it has a destination field.
  final ValueChanged<TransactionEntity>? onOpen;

  /// Swiping a row away, or the screen reader's delete action. Completes true once the row is deleted; false puts a swiped row back.
  final Future<bool> Function(TransactionEntity transaction)? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radii.borderLg;
    final onOpen = this.onOpen;
    final onDelete = this.onDelete;

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
              children: <Widget>[
                for (var i = 0; i < transactions.length; i++)
                  _DeletableRow(
                    key: ValueKey<String>(transactions[i].id),
                    transaction: transactions[i],
                    onDelete: onDelete,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: i == 0 ? null : Border(top: BorderSide(color: colors.outlineVariant)),
                      ),
                      child: TransactionRow(
                        transaction: transactions[i],
                        onTap: onOpen == null || transactions[i].type == TransactionType.transfer ? null : () => onOpen(transactions[i]),
                      ),
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
class _DeletableRow extends StatelessWidget {
  const _DeletableRow({required this.transaction, required this.onDelete, required this.child, super.key});

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
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{CustomSemanticsAction(label: label): () => onDelete(transaction)},
      child: Dismissible(
        key: ValueKey<String>('dismiss-${transaction.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => onDelete(transaction),
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
class TransactionRow extends StatelessWidget {
  const TransactionRow({required this.transaction, this.onTap, super.key});

  static const double minHeight = 56;

  final TransactionEntity transaction;
  final VoidCallback? onTap;

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
          children: <Widget>[
            if (transaction.type == TransactionType.transfer) ...<Widget>[
              Icon(Icons.swap_horiz, size: 18, color: colors.onSurfaceVariant),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                transaction.titleIn(context.l10n),
                style: textStyle.copyWith(color: colors.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: spacing.smd),
            GPMoneyText(
              transaction.amount,
              tone: transaction.moneyTone,
              style: textStyle.copyWith(fontWeight: FontWeight.w600, color: colors.onSurface),
            ),
          ],
        ),
      ),
    );

    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// Sits above the rows and never replaces them.
class TransactionListBanner extends StatelessWidget {
  /// The query failed while rows were already on screen.
  const TransactionListBanner.error({required this.message, super.key}) : _isError = true;

  /// Some rows could not be read (ADR-0011).
  const TransactionListBanner.notice({required this.message, super.key}) : _isError = false;

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
        margin: EdgeInsets.fromLTRB(spacing.md, spacing.xs, spacing.md, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: background, borderRadius: context.radii.borderMd),
        child: Row(
          children: <Widget>[
            Icon(_isError ? Icons.error_outline : Icons.info_outline, size: 20, color: foreground),
            const SizedBox(width: 10),
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
class TransactionListFooter extends StatelessWidget {
  const TransactionListFooter({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: context.spacing.md + context.spacing.xs),
    child: Center(
      child: Semantics(
        label: label,
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onSurfaceVariant),
        ),
      ),
    ),
  );
}

/// First load, or the moments after a filter change.
class TransactionListSkeleton extends StatelessWidget {
  const TransactionListSkeleton({super.key});

  /// Title and amount bar widths per row: uneven on purpose, so it reads as text rather than a grid.
  static const List<List<(double, double)>> _days = <List<(double, double)>>[
    <(double, double)>[(120, 72), (168, 64), (96, 80)],
    <(double, double)>[(140, 96), (184, 72), (112, 64)],
    <(double, double)>[(200, 64), (88, 72)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radii.borderLg;

    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: context.radii.borderSm),
    );

    return Semantics(
      container: true,
      label: context.l10n.transactions.loading,
      child: ExcludeSemantics(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final rows in _days) ...<Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(spacing.md, spacing.md + spacing.xs, spacing.md, 10),
                  child: bar(88, 12),
                ),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: spacing.md),
                  decoration: BoxDecoration(color: colors.surface, borderRadius: radius, boxShadow: context.shadows.small),
                  child: Column(
                    children: <Widget>[
                      for (final (title, amount) in rows)
                        SizedBox(
                          height: TransactionRow.minHeight,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: spacing.md),
                            child: Row(children: <Widget>[bar(title, 14), const Spacer(), bar(amount, 14)]),
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
