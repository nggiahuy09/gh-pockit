import 'package:flutter/material.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/theme/tokens/dimensions.dart';
import 'package:ghpockit/core/widgets/focus_ring.dart';

/// 40 tall: lay chips out 8 apart, with at least 4 above and below the row, so each still owns a 48 touch target.
/// Single choice and multi choice are the caller's: a chip only knows whether it is [selected].
class GPChip extends StatefulWidget {
  const GPChip({required this.label, this.selected = false, this.onPressed, this.onDeleted, this.leading, this.trailing, this.enabled = true, super.key});

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  /// Shows a remove button at the end, in place of [trailing]: a filter that is on.
  final VoidCallback? onDeleted;

  final IconData? leading;
  final IconData? trailing;
  final bool enabled;

  @override
  State<GPChip> createState() => _GPChipState();
}

class _GPChipState extends State<GPChip> {
  bool _pressed = false;
  bool _hovered = false;
  bool _showFocus = false;

  bool get _interactive => widget.enabled && widget.onPressed != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = widget.enabled;
    final selected = widget.selected;
    final foreground = !enabled
        ? colors.onSurfaceVariant
        : selected
        ? colors.onAccentContainer
        : colors.onBackground;
    final fill = selected && enabled ? colors.accentContainer : Colors.transparent;
    final overlay = selected || !_interactive
        ? Colors.transparent
        : _pressed
        ? colors.onBackground.withValues(alpha: 0.08)
        : _hovered
        ? colors.onBackground.withValues(alpha: 0.06)
        : Colors.transparent;
    final edge = selected && enabled
        ? Colors.transparent
        : enabled
        ? colors.outline
        : colors.outlineVariant;
    final hasTrailing = widget.onDeleted != null || widget.trailing != null;

    final chip = AnimatedContainer(
      duration: GPDurationTokens.fast,
      height: 40,
      padding: EdgeInsetsDirectional.only(start: widget.leading != null ? 11 : 15, end: hasTrailing ? 9 : 15),
      decoration: BoxDecoration(
        color: Color.alphaBlend(overlay, fill),
        borderRadius: context.radii.borderFull,
        border: Border.all(color: edge),
        boxShadow: _showFocus ? focusRingShadows(ring: colors.accentInk, gap: colors.background) : const <BoxShadow>[],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (widget.leading != null) ...<Widget>[
            Icon(widget.leading, size: 18, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(widget.label, maxLines: 1, style: context.text.labelLarge.copyWith(color: foreground)),
          if (widget.onDeleted != null) ...<Widget>[
            const SizedBox(width: 6),
            _GPChipRemoveButton(label: widget.label, color: foreground, onPressed: enabled ? widget.onDeleted : null),
          ] else if (widget.trailing != null) ...<Widget>[
            const SizedBox(width: 6),
            Icon(widget.trailing, size: 18, color: foreground),
          ],
        ],
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Semantics(
        button: widget.onPressed != null,
        selected: selected,
        enabled: _interactive,
        child: FocusableActionDetector(
          enabled: _interactive,
          mouseCursor: _interactive ? SystemMouseCursors.click : MouseCursor.defer,
          onShowFocusHighlight: (bool value) => setState(() => _showFocus = value),
          onShowHoverHighlight: (bool value) => setState(() => _hovered = value),
          actions: <Type, Action<Intent>>{ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed?.call())},
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _interactive ? widget.onPressed : null,
            onTapDown: _interactive ? (_) => _setPressed(true) : null,
            onTapUp: _interactive ? (_) => _setPressed(false) : null,
            onTapCancel: _interactive ? () => _setPressed(false) : null,
            child: chip,
          ),
        ),
      ),
    );
  }
}

class _GPChipRemoveButton extends StatelessWidget {
  const _GPChipRemoveButton({required this.label, required this.color, required this.onPressed});

  final String label;
  final Color color;
  final VoidCallback? onPressed;

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
        dimension: 24,
        child: Icon(Icons.close, size: 18, color: color),
      ),
    ),
  );
}
