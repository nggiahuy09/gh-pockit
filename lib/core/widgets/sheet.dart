import 'package:flutter/material.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/theme_context.dart';

/// In Pockit a sheet is for picking and a dialog for deciding. A swipe down, the scrim or Back closes it with null: the caller keeps its old value.
Future<T?> showGPSheet<T>({required BuildContext context, required WidgetBuilder builder, String? title}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  elevation: 0,
  barrierColor: context.colors.scrim,
  barrierLabel: context.l10n.widgets.dismiss,
  builder: (BuildContext context) => GPSheet(title: title, child: builder(context)),
);

/// The sheet's own chrome: surface, top corners xl, a drag handle and an optional title. Light lifts it with a shadow; dark edges it in outline.
class GPSheet extends StatelessWidget {
  const GPSheet({required this.child, this.title, super.key});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = Radius.circular(context.radii.xl);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(top: radius),
        border: context.isDark ? Border.all(color: colors.outline) : null,
        // extraLarge cast upward, off the bottom edge it sits on. Dark's list is empty.
        boxShadow: <BoxShadow>[
          for (final shadow in context.shadows.extraLarge) BoxShadow(color: shadow.color, blurRadius: shadow.blurRadius, spreadRadius: shadow.spreadRadius, offset: -shadow.offset),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(context.spacing.sm, context.spacing.sm, context.spacing.sm, context.spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: EdgeInsets.only(top: context.spacing.xs, bottom: context.spacing.smd),
                  decoration: BoxDecoration(color: colors.outline, borderRadius: context.radii.borderFull),
                ),
              ),
              if (title != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.xs, context.spacing.md, context.spacing.smd),
                  child: Semantics(
                    header: true,
                    child: Text(title!, style: context.text.titleLarge.copyWith(color: colors.onSurface)),
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
