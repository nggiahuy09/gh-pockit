import 'package:flutter/material.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/widgets/button.dart';

/// Also the error state: pass the failure's message as [message] and a retry as [onAction].
class GPEmptyState extends StatelessWidget {
  const GPEmptyState({required this.icon, required this.title, this.message, this.actionLabel, this.onAction, super.key})
    : assert(
        (actionLabel == null) == (onAction == null),
        'GPEmptyState needs both actionLabel and onAction, or neither — a labelled button that does nothing is worse than no button.',
      );

  final Widget icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: spacing.xl, vertical: spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconTheme.merge(
              data: IconThemeData(size: 40, color: colors.onSurfaceVariant),
              child: icon,
            ),
            SizedBox(height: spacing.md),
            Text(
              title,
              style: context.text.titleLarge.copyWith(color: colors.onBackground),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...<Widget>[
              SizedBox(height: spacing.sm),
              Text(
                message!,
                style: context.text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (onAction != null) ...<Widget>[
              SizedBox(height: spacing.lg),
              GPButton(label: actionLabel!, onPressed: onAction, variant: GPButtonVariant.tonal),
            ],
          ],
        ),
      ),
    );
  }
}
