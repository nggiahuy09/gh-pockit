import 'package:flutter/material.dart';

import '../localization/localization_scope.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/dimensions.dart';
import 'button.dart';

enum GPDialogTone { info, warning, danger }

@immutable
final class GPDialogAction<T> {
  const GPDialogAction({required this.value, this.variant = GPButtonVariant.primary, required this.label});

  /// The way out: tonal, and the value a tap on the scrim or Back also stands for.
  const GPDialogAction.cancel({required this.value, required this.label}) : variant = GPButtonVariant.tonal;

  final T value;
  final GPButtonVariant variant;
  final String label;

  bool get isDestructive => variant == GPButtonVariant.danger;
}

/// For a decision the user must make before going on, with one or two [actions] listed cancel first. Picking belongs in a sheet, "done" in a
/// snackbar, a bad field under the field. The scrim and Back close it with null, which callers read as cancel.
Future<T?> showGPDialog<T>({
  required List<GPDialogAction<T>> actions,
  Widget? content,
  required BuildContext context,
  IconData? icon,
  GPDialogTone tone = GPDialogTone.info,
  String? message,
  required String title,
}) {
  assert(actions.isNotEmpty && actions.length <= 2, 'A dialog takes one or two actions; three or more belong in a sheet.');

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.widgets.dismiss,
    barrierColor: context.colors.scrim,
    transitionDuration: GPDurationTokens.normal,
    pageBuilder: (_, _, _) => GPDialog(actions: actions, content: content, icon: icon, tone: tone, message: message, title: title),
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

final class GPDialog<T> extends StatelessWidget {
  const GPDialog({super.key, required this.actions, this.content, this.icon, this.tone = GPDialogTone.info, this.message, required this.title});

  final List<GPDialogAction<T>> actions;

  /// Under the message: what the decision is about, when a sentence cannot show it (the row a swipe is deleting).
  final Widget? content;

  final IconData? icon;
  final GPDialogTone tone;
  final String? message;
  final String title;

  static const maxWidth = 400.0;

  /// Focus starts on cancel when the other choice destroys data, so Enter cannot delete; otherwise on the choice the dialog is asking for.
  int get _initialFocus {
    final cancel = actions.indexWhere((action) => action.variant == GPButtonVariant.tonal);
    return actions.any((action) => action.isDestructive) && cancel >= 0 ? cancel : actions.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final content = this.content;
    final icon = this.icon;
    final message = this.message;
    final iconColor = switch (tone) {
      GPDialogTone.info => colors.onSurfaceVariant,
      GPDialogTone.warning => colors.warning,
      GPDialogTone.danger => colors.danger,
    };

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: title,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: context.radii.borderXl,
                border: context.isDark ? Border.all(color: colors.outline) : null,
                boxShadow: context.shadows.extraLarge,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Padding(
                  padding: EdgeInsets.all(spacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (icon != null) ...[
                        SizedBox.square(
                          dimension: 40.0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: colors.surfaceVariant, shape: BoxShape.circle),
                            child: Icon(icon, size: 24.0, color: iconColor),
                          ),
                        ),
                        SizedBox(height: spacing.md),
                      ],
                      Text(title, style: context.text.titleLarge.copyWith(color: colors.onSurface)),
                      if (message != null) ...[
                        SizedBox(height: spacing.sm),
                        Text(message, style: context.text.bodyMedium.copyWith(color: colors.onSurfaceVariant)),
                      ],
                      if (content != null) ...[
                        SizedBox(height: spacing.smd),
                        DefaultTextStyle.merge(
                          style: context.text.bodyMedium.copyWith(color: colors.onSurface),
                          child: content,
                        ),
                      ],
                      SizedBox(height: spacing.lg),
                      _GPDialogActions(actions: actions, initialFocus: _initialFocus),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One action: full width. Two that both fit half the width: side by side, cancel on the left. Otherwise stacked, the answer on top.
final class _GPDialogActions<T> extends StatelessWidget {
  const _GPDialogActions({required this.actions, required this.initialFocus});

  final List<GPDialogAction<T>> actions;
  final int initialFocus;

  /// GPButton medium's horizontal padding, both sides.
  static const _buttonPadding = 40.0;

  bool _fitsSideBySide(BuildContext context, double width) {
    final half = (width - context.spacing.smd) / 2;
    final style = context.text.titleMedium.copyWith(fontWeight: FontWeight.w600);
    final scaler = MediaQuery.textScalerOf(context);

    return actions.every((action) {
      final painter = TextPainter(
        text: TextSpan(text: action.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final fits = painter.width + _buttonPadding <= half;
      painter.dispose();
      return fits;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (actions.length == 1) return _GPDialogButton(action: actions.single, isAutofocused: initialFocus == 0);

    final gap = context.spacing.smd;
    return LayoutBuilder(
      builder: (_, constraints) => _fitsSideBySide(context, constraints.maxWidth)
          ? Row(
              spacing: gap,
              children: [
                for (var index = 0; index < actions.length; index++)
                  Expanded(
                    child: _GPDialogButton(action: actions[index], isAutofocused: index == initialFocus),
                  ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              spacing: gap,
              children: [
                for (var index = actions.length - 1; index >= 0; index--) _GPDialogButton(action: actions[index], isAutofocused: index == initialFocus),
              ],
            ),
    );
  }
}

final class _GPDialogButton<T> extends StatelessWidget {
  const _GPDialogButton({required this.action, required this.isAutofocused});

  final GPDialogAction<T> action;
  final bool isAutofocused;

  @override
  Widget build(BuildContext context) => GPButton(
    variant: action.variant,
    label: action.label,
    autofocus: isAutofocused,
    expanded: true,
    onPressed: () => Navigator.of(context).pop(action.value),
  );
}
