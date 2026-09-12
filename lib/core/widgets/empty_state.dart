import 'package:flutter/material.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/widgets/button.dart';

/// The "there is nothing here" screen.
///
/// Not ported from `ngh09_ui_kit` — the kit has no equivalent, because an empty state is an app concern rather than a component-library one. It is
/// here in W1 because CLAUDE.md §11 makes "loading / error / empty states have UI" part of the definition of done, and W5 ships the first list that
/// can be empty. Writing it once now is cheaper than writing it five times later, differently each time.
///
/// Takes strings, not l10n keys. `core/` must not know which feature is rendering it, and the caller already has `l10n` in scope — passing
/// the resolved string keeps this widget free of the localization contract and testable without pumping a locale.
///
/// The same widget serves the error case: pass the failure's message as [message] and a retry as [onAction]. An empty list and a failed load look
/// different to a developer and identical to a user — both are "no rows, here is what to do about it".
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
