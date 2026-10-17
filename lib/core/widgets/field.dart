import 'package:flutter/material.dart';
import 'package:ghpockit/core/theme/colors.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/theme/tokens/dimensions.dart';

enum GPFieldState {
  idle,

  /// Typing in it, or its picker is open.
  active,
  error,
  disabled,
}

/// Label above, box, then one line of help or error. The label never floats into the box: it stays where it was when the user started typing.
class GPField extends StatelessWidget {
  const GPField({required this.child, this.label, this.helperText, this.errorText, this.counterText, this.mergeSemantics = false, super.key});

  final Widget child;
  final String? label;
  final String? helperText;

  /// Wins over [helperText].
  final String? errorText;

  final String? counterText;

  /// Reads label, input and help as one node: for a [child] that announces no label of its own, like a `TextField` with none.
  final bool mergeSemantics;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final text = context.text;
    final hasMeta = errorText != null || helperText != null || counterText != null;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (label != null) ...<Widget>[
          // Unless merged, the box announces the label itself, so a screen reader does not read it twice.
          ExcludeSemantics(
            excluding: !mergeSemantics,
            child: Text(label!, style: text.labelLarge.copyWith(color: colors.onSurfaceVariant)),
          ),
          SizedBox(height: spacing.sm),
        ],
        child,
        if (hasMeta) ...<Widget>[
          SizedBox(height: spacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: errorText != null
                    ? Semantics(
                        liveRegion: true,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(Icons.error_outline, size: 16, color: colors.danger),
                            ),
                            SizedBox(width: spacing.xs),
                            Expanded(
                              child: Text(errorText!, style: text.bodySmall.copyWith(color: colors.danger)),
                            ),
                          ],
                        ),
                      )
                    : Text(helperText ?? '', style: text.bodySmall.copyWith(color: colors.onSurfaceVariant)),
              ),
              if (counterText != null) ...<Widget>[
                SizedBox(width: spacing.smd),
                Text(
                  counterText!,
                  style: text.bodySmall.copyWith(color: colors.onSurfaceVariant, fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]),
                ),
              ],
            ],
          ),
        ],
      ],
    );
    return mergeSemantics ? MergeSemantics(child: column) : column;
  }
}

/// The box every input shares: surface, 1px outline, radius md, at least 56 tall. Active and error draw a 2px edge instead.
class GPFieldBox extends StatelessWidget {
  const GPFieldBox({required this.state, required this.child, super.key});

  static const double minHeight = 56;

  final GPFieldState state;
  final Widget child;

  static BoxDecoration decorationOf(GPColors colors, BorderRadius radius, GPFieldState state) {
    final edge = switch (state) {
      GPFieldState.idle => Border.all(color: colors.outline),
      GPFieldState.active => Border.all(color: colors.accentInk, width: 2),
      GPFieldState.error => Border.all(color: colors.danger, width: 2),
      GPFieldState.disabled => Border.all(color: Colors.transparent),
    };
    return BoxDecoration(color: state == GPFieldState.disabled ? colors.surfaceVariant : colors.surface, borderRadius: radius, border: edge);
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: GPDurationTokens.fast,
    constraints: const BoxConstraints(minHeight: minHeight),
    // A border pads a Container by its width: the inset shrinks by the extra pixel of a 2px edge so the content does not shift when focus lands.
    padding: EdgeInsets.only(
      left: state == GPFieldState.active || state == GPFieldState.error ? 15 : 16,
      right: state == GPFieldState.active || state == GPFieldState.error ? 11 : 12,
    ),
    decoration: decorationOf(context.colors, context.radii.borderMd, state),
    alignment: AlignmentDirectional.centerStart,
    child: child,
  );
}

/// A field that opens something rather than taking typing: a select, a date. Shows the value (or a placeholder), an optional leading icon and a
/// chevron that turns while [isOpen].
class GPPickerField extends StatelessWidget {
  const GPPickerField({
    required this.onTap,
    this.label,
    this.value,
    this.placeholder,
    this.leading,
    this.isOpen = false,
    this.helperText,
    this.errorText,
    this.focusNode,
    super.key,
  });

  /// Null disables the field.
  final VoidCallback? onTap;
  final String? label;
  final String? value;
  final String? placeholder;
  final IconData? leading;
  final bool isOpen;
  final String? helperText;
  final String? errorText;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onTap != null;
    final state = !enabled
        ? GPFieldState.disabled
        : errorText != null
        ? GPFieldState.error
        : isOpen
        ? GPFieldState.active
        : GPFieldState.idle;
    final shown = value ?? placeholder ?? '';

    return GPField(
      label: label,
      helperText: helperText,
      errorText: errorText,
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
            overlayColor: WidgetStatePropertyAll<Color>(colors.onSurface.withValues(alpha: 0.06)),
            child: GPFieldBox(
              state: state,
              child: Row(
                children: <Widget>[
                  if (leading != null) ...<Widget>[
                    Icon(leading, size: 20, color: colors.onSurfaceVariant),
                    SizedBox(width: context.spacing.smd),
                  ],
                  Expanded(
                    child: Text(
                      shown,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyLarge.copyWith(color: value == null || !enabled ? colors.onSurfaceVariant : colors.onSurface),
                    ),
                  ),
                  SizedBox(width: context.spacing.smd),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: GPDurationTokens.normal,
                    child: Icon(Icons.expand_more, size: 24, color: colors.onSurfaceVariant),
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
