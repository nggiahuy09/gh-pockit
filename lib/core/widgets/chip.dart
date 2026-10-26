import 'package:flutter/material.dart';

import '../localization/localization_scope.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/dimensions.dart';
import 'focus_ring.dart';

/// 40 tall: lay chips out 8 apart, with at least 4 above and below the row, so each still owns a 48 touch target. Single or multi choice is the
/// caller's: a chip only knows whether it is [selected].
final class GPChip extends StatefulWidget {
  const GPChip({super.key, this.leading, this.trailing, required this.label, this.enabled = true, this.selected = false, this.onDeleted, this.onPressed});

  final IconData? leading;
  final IconData? trailing;
  final String label;
  final bool enabled;
  final bool selected;

  /// Shows a remove button at the end, in place of [trailing]: a filter that is on.
  final void Function()? onDeleted;

  final void Function()? onPressed;

  @override
  State<GPChip> createState() => _GPChipState();
}

final class _GPChipState extends State<GPChip> {
  var _isHovered = false;
  var _isPressed = false;
  var _showsFocus = false;

  bool get _isInteractive => widget.enabled && widget.onPressed != null;

  void _setPressed(bool isPressed) {
    if (_isPressed != isPressed) setState(() => _isPressed = isPressed);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = widget.enabled;
    final selected = widget.selected;
    final leading = widget.leading;
    final trailing = widget.trailing;
    final foreground = !enabled
        ? colors.onSurfaceVariant
        : selected
        ? colors.onAccentContainer
        : colors.onBackground;
    final fill = selected && enabled ? colors.accentContainer : Colors.transparent;
    final overlay = selected || !_isInteractive
        ? Colors.transparent
        : _isPressed
        ? colors.onBackground.withValues(alpha: 0.08)
        : _isHovered
        ? colors.onBackground.withValues(alpha: 0.06)
        : Colors.transparent;
    final edge = selected && enabled
        ? Colors.transparent
        : enabled
        ? colors.outline
        : colors.outlineVariant;
    final hasTrailing = widget.onDeleted != null || trailing != null;

    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: Semantics(
        button: widget.onPressed != null,
        selected: selected,
        enabled: _isInteractive,
        child: FocusableActionDetector(
          enabled: _isInteractive,
          mouseCursor: _isInteractive ? SystemMouseCursors.click : MouseCursor.defer,
          onShowFocusHighlight: (value) => setState(() => _showsFocus = value),
          onShowHoverHighlight: (value) => setState(() => _isHovered = value),
          actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed?.call())},
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isInteractive ? widget.onPressed : null,
            onTapDown: _isInteractive ? (_) => _setPressed(true) : null,
            onTapUp: _isInteractive ? (_) => _setPressed(false) : null,
            onTapCancel: _isInteractive ? () => _setPressed(false) : null,
            child: AnimatedContainer(
              duration: GPDurationTokens.fast,
              height: 40.0,
              padding: EdgeInsetsDirectional.only(start: leading != null ? 11.0 : 15.0, end: hasTrailing ? 9.0 : 15.0),
              decoration: BoxDecoration(
                color: Color.alphaBlend(overlay, fill),
                borderRadius: context.radii.borderFull,
                border: Border.all(color: edge),
                boxShadow: _showsFocus ? focusRingShadows(gap: colors.background, ring: colors.accentInk) : const [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6.0,
                children: [
                  if (leading != null) Icon(leading, size: 18.0, color: foreground),
                  Text(widget.label, maxLines: 1, style: context.text.labelLarge.copyWith(color: foreground)),
                  if (widget.onDeleted != null)
                    _GPChipRemoveButton(color: foreground, label: widget.label, onPressed: enabled ? widget.onDeleted : null)
                  else if (trailing != null)
                    Icon(trailing, size: 18.0, color: foreground),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _GPChipRemoveButton extends StatelessWidget {
  const _GPChipRemoveButton({required this.color, required this.label, required this.onPressed});

  final Color color;
  final String label;
  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: context.l10n.widgets.removeFilter(label),
    excludeSemantics: true,
    onTap: onPressed,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: 24.0,
        child: Icon(Icons.close, size: 18.0, color: color),
      ),
    ),
  );
}
