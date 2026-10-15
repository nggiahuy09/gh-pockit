import 'package:flutter/material.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/theme/tokens/dimensions.dart';
import 'package:ghpockit/core/widgets/button.dart';

enum GPDialogTone { info, warning, danger }

@immutable
class GPDialogAction<T> {
  const GPDialogAction({required this.label, required this.value, this.variant = GPButtonVariant.primary});

  /// The way out: tonal, and the value a tap on the scrim or Back also stands for.
  const GPDialogAction.cancel({required this.label, required this.value}) : variant = GPButtonVariant.tonal;

  final String label;
  final T value;
  final GPButtonVariant variant;

  bool get isDestructive => variant == GPButtonVariant.danger;
}

/// For a decision the user must make before going on, with one or two [actions] listed cancel first. Picking belongs in a sheet, "done" in a
/// snackbar, a bad field under the field. The scrim and Back close it with null, which callers read as cancel.
Future<T?> showGPDialog<T>({
  required BuildContext context,
  required String title,
  required List<GPDialogAction<T>> actions,
  String? message,
  Widget? content,
  IconData? icon,
  GPDialogTone tone = GPDialogTone.info,
}) {
  assert(actions.isNotEmpty && actions.length <= 2, 'A dialog takes one or two actions; three or more belong in a sheet.');

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.widgets.dismiss,
    barrierColor: context.colors.scrim,
    transitionDuration: GPDurationTokens.normal,
    pageBuilder: (BuildContext context, _, _) => GPDialog<T>(title: title, message: message, content: content, icon: icon, tone: tone, actions: actions),
    transitionBuilder: (BuildContext context, Animation<double> animation, _, Widget child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1).animate(curved), child: child),
      );
    },
  );
}

class GPDialog<T> extends StatelessWidget {
  const GPDialog({required this.title, required this.actions, this.message, this.content, this.icon, this.tone = GPDialogTone.info, super.key});

  static const double maxWidth = 400;

  final String title;
  final String? message;

  /// Under the message: what the decision is about, when a sentence cannot show it (the row a swipe is deleting).
  final Widget? content;

  final IconData? icon;
  final GPDialogTone tone;
  final List<GPDialogAction<T>> actions;

  /// Focus starts on cancel when the other choice destroys data, so Enter cannot delete; otherwise on the choice the dialog is asking for.
  int get _initialFocus {
    final destroys = actions.any((GPDialogAction<T> action) => action.isDestructive);
    final cancel = actions.indexWhere((GPDialogAction<T> action) => action.variant == GPButtonVariant.tonal);
    return destroys && cancel >= 0 ? cancel : actions.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
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
                    children: <Widget>[
                      if (icon != null) ...<Widget>[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: colors.surfaceVariant, shape: BoxShape.circle),
                          child: Icon(icon, size: 24, color: iconColor),
                        ),
                        SizedBox(height: spacing.md),
                      ],
                      Text(title, style: context.text.titleLarge.copyWith(color: colors.onSurface)),
                      if (message != null) ...<Widget>[
                        SizedBox(height: spacing.sm),
                        Text(message!, style: context.text.bodyMedium.copyWith(color: colors.onSurfaceVariant)),
                      ],
                      if (content != null) ...<Widget>[
                        SizedBox(height: spacing.smd),
                        DefaultTextStyle.merge(
                          style: context.text.bodyMedium.copyWith(color: colors.onSurface),
                          child: content!,
                        ),
                      ],
                      SizedBox(height: spacing.lg),
                      _GPDialogActions<T>(actions: actions, initialFocus: _initialFocus),
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
class _GPDialogActions<T> extends StatelessWidget {
  const _GPDialogActions({required this.actions, required this.initialFocus});

  /// GPButton medium's horizontal padding, both sides.
  static const double _buttonPadding = 40;

  final List<GPDialogAction<T>> actions;
  final int initialFocus;

  Widget _button(BuildContext context, int index) {
    final action = actions[index];
    return GPButton(
      label: action.label,
      variant: action.variant,
      expanded: true,
      autofocus: index == initialFocus,
      onPressed: () => Navigator.of(context).pop(action.value),
    );
  }

  bool _fitsSideBySide(BuildContext context, double width) {
    final gap = context.spacing.smd;
    final half = (width - gap) / 2;
    final style = context.text.titleMedium.copyWith(fontWeight: FontWeight.w600);
    final scaler = MediaQuery.textScalerOf(context);

    return actions.every((GPDialogAction<T> action) {
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
    if (actions.length == 1) return _button(context, 0);

    final gap = context.spacing.smd;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (_fitsSideBySide(context, constraints.maxWidth)) {
          return Row(
            children: <Widget>[
              Expanded(child: _button(context, 0)),
              SizedBox(width: gap),
              Expanded(child: _button(context, 1)),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final index in List<int>.generate(actions.length, (int i) => i).reversed) ...<Widget>[
              _button(context, index),
              if (index != 0) SizedBox(height: gap),
            ],
          ],
        );
      },
    );
  }
}
