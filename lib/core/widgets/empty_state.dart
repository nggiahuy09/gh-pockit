import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import 'button.dart';

/// Also the error state: pass the failure's message as [message] and a retry as [onAction].
final class GPEmptyState extends StatelessWidget {
  const GPEmptyState({super.key, required this.icon, this.actionLabel, this.message, required this.title, this.onAction})
    : assert((actionLabel == null) == (onAction == null), 'GPEmptyState needs both actionLabel and onAction, or neither: a labelled button that does nothing is worse than none.');

  final Widget icon;
  final String? actionLabel;
  final String? message;
  final String title;
  final void Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final actionLabel = this.actionLabel;
    final message = this.message;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: spacing.xl, vertical: spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme.merge(
              data: IconThemeData(size: 40.0, color: colors.onSurfaceVariant),
              child: icon,
            ),
            SizedBox(height: spacing.md),
            Text(
              title,
              style: context.text.titleLarge.copyWith(color: colors.onBackground),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              SizedBox(height: spacing.sm),
              Text(
                message,
                style: context.text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null) ...[
              SizedBox(height: spacing.lg),
              GPButton(variant: GPButtonVariant.tonal, label: actionLabel, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
