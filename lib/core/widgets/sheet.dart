import 'package:flutter/material.dart';

import '../localization/localization_scope.dart';
import '../theme/theme_context.dart';

/// In Pockit a sheet is for picking and a dialog for deciding. A swipe down, the scrim or Back closes it with null: the caller keeps its old value.
Future<T?> showGPSheet<T>({required BuildContext context, String? title, required WidgetBuilder builder}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  elevation: 0.0,
  barrierColor: context.colors.scrim,
  barrierLabel: context.l10n.widgets.dismiss,
  builder: (context) => GPSheet(title: title, child: builder.call(context)),
);

/// Light lifts it with a shadow; dark edges it in outline.
final class GPSheet extends StatelessWidget {
  const GPSheet({super.key, this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = Radius.circular(context.radii.xl);
    final title = this.title;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(top: radius),
        border: context.isDark ? Border.all(color: colors.outline) : null,
        // extraLarge cast upward, off the bottom edge it sits on. Dark's list is empty.
        boxShadow: [
          for (final shadow in context.shadows.extraLarge) BoxShadow(color: shadow.color, blurRadius: shadow.blurRadius, spreadRadius: shadow.spreadRadius, offset: -shadow.offset),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(spacing.sm, spacing.sm, spacing.sm, spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36.0,
                  height: 4.0,
                  margin: EdgeInsets.only(top: spacing.xs, bottom: spacing.smd),
                  decoration: BoxDecoration(color: colors.outline, borderRadius: context.radii.borderFull),
                ),
              ),
              if (title != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(spacing.md, spacing.xs, spacing.md, spacing.smd),
                  child: Semantics(
                    header: true,
                    child: Text(title, style: context.text.titleLarge.copyWith(color: colors.onSurface)),
                  ),
                ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
