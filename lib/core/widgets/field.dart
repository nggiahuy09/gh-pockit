import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/dimensions.dart';

enum GPFieldState {
  idle,

  /// Typing in it, or its picker is open.
  active,

  error,
  disabled,
}

/// Label above, box, then one line of help or error. The label never floats into the box: it stays where it was when the user started typing.
final class GPField extends StatelessWidget {
  const GPField({super.key, this.counterText, this.errorText, this.helperText, this.label, this.mergeSemantics = false, required this.child});

  final String? counterText;

  /// Wins over [helperText].
  final String? errorText;

  final String? helperText;
  final String? label;

  /// Reads label, input and help as one node: for a [child] that announces no label of its own, like a `TextField` with none.
  final bool mergeSemantics;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final text = context.text;
    final counterText = this.counterText;
    final errorText = this.errorText;
    final label = this.label;
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: spacing.sm,
      children: [
        if (label != null)
          // Unless merged, the box announces the label itself, so a screen reader does not read it twice.
          ExcludeSemantics(
            excluding: !mergeSemantics,
            child: Text(label, style: text.labelLarge.copyWith(color: colors.onSurfaceVariant)),
          ),
        child,
        if (errorText != null || helperText != null || counterText != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: spacing.smd,
            children: [
              Expanded(
                child: errorText != null
                    ? Semantics(
                        liveRegion: true,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: spacing.xs,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1.0),
                              child: Icon(Icons.error_outline, size: 16.0, color: colors.danger),
                            ),
                            Expanded(
                              child: Text(errorText, style: text.bodySmall.copyWith(color: colors.danger)),
                            ),
                          ],
                        ),
                      )
                    : Text(helperText ?? '', style: text.bodySmall.copyWith(color: colors.onSurfaceVariant)),
              ),
              if (counterText != null)
                Text(
                  counterText,
                  style: text.bodySmall.copyWith(color: colors.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
            ],
          ),
      ],
    );

    return mergeSemantics ? MergeSemantics(child: column) : column;
  }
}

/// The box every input shares: surface, 1px outline, radius md, at least 56 tall. Active and error draw a 2px edge instead.
final class GPFieldBox extends StatelessWidget {
  const GPFieldBox({super.key, required this.state, required this.child});

  final GPFieldState state;
  final Widget child;

  static const minHeight = 56.0;

  bool get _hasThickEdge => state == GPFieldState.active || state == GPFieldState.error;

  BoxDecoration _decorationOf(BorderRadius radius, GPColors colors) => BoxDecoration(
    color: state == GPFieldState.disabled ? colors.surfaceVariant : colors.surface,
    borderRadius: radius,
    border: switch (state) {
      GPFieldState.idle => Border.all(color: colors.outline),
      GPFieldState.active => Border.all(color: colors.accentInk, width: 2.0),
      GPFieldState.error => Border.all(color: colors.danger, width: 2.0),
      GPFieldState.disabled => Border.all(color: Colors.transparent),
    },
  );

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: GPDurationTokens.fast,
    constraints: const BoxConstraints(minHeight: minHeight),
    // A border pads a Container by its width: the inset shrinks by the extra pixel of a 2px edge so the content does not shift when focus lands.
    padding: EdgeInsets.only(left: _hasThickEdge ? 15.0 : 16.0, right: _hasThickEdge ? 11.0 : 12.0),
    decoration: _decorationOf(context.radii.borderMd, context.colors),
    alignment: AlignmentDirectional.centerStart,
    child: child,
  );
}

/// A field that opens something rather than taking typing: a select, a date. The chevron turns while [isOpen].
final class GPPickerField extends StatelessWidget {
  const GPPickerField({
    super.key,
    this.focusNode,
    this.leading,
    this.errorText,
    this.helperText,
    this.label,
    this.placeholder,
    this.value,
    this.isOpen = false,
    required this.onTap,
  });

  final FocusNode? focusNode;
  final IconData? leading;
  final String? errorText;
  final String? helperText;
  final String? label;
  final String? placeholder;
  final String? value;
  final bool isOpen;

  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onTap != null;
    final leading = this.leading;
    final state = !enabled
        ? GPFieldState.disabled
        : errorText != null
        ? GPFieldState.error
        : isOpen
        ? GPFieldState.active
        : GPFieldState.idle;
    final shown = value ?? placeholder ?? '';

    return GPField(
      errorText: errorText,
      helperText: helperText,
      label: label,
      child: Semantics(
        button: true,
        enabled: enabled,
        expanded: isOpen,
        label: label,
        value: shown,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            focusNode: focusNode,
            borderRadius: context.radii.borderMd,
            overlayColor: WidgetStatePropertyAll(colors.onSurface.withValues(alpha: 0.06)),
            child: GPFieldBox(
              state: state,
              child: Row(
                spacing: context.spacing.smd,
                children: [
                  if (leading != null) Icon(leading, size: 20.0, color: colors.onSurfaceVariant),
                  Expanded(
                    child: Text(
                      shown,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyLarge.copyWith(color: value == null || !enabled ? colors.onSurfaceVariant : colors.onSurface),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0.0,
                    duration: GPDurationTokens.normal,
                    child: Icon(Icons.expand_more, size: 24.0, color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
