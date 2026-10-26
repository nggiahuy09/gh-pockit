import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/dimensions.dart';
import 'focus_ring.dart';

/// 52×32, under the 48 touch target in height: prefer [GPSwitchRow], which makes the whole row the target.
final class GPSwitch extends StatefulWidget {
  const GPSwitch({super.key, this.semanticLabel, this.autofocus = false, required this.value, required this.onChanged});

  final String? semanticLabel;
  final bool autofocus;
  final bool value;

  final void Function(bool value)? onChanged;

  @override
  State<GPSwitch> createState() => _GPSwitchState();
}

final class _GPSwitchState extends State<GPSwitch> {
  var _showsFocus = false;

  void _handleToggle() => widget.onChanged?.call(!widget.value);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;

    return Semantics(
      toggled: widget.value,
      enabled: enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        autofocus: widget.autofocus,
        onShowFocusHighlight: (value) => setState(() => _showsFocus = value),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _handleToggle())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _handleToggle : null,
          child: GPSwitchTrack(enabled: enabled, showFocus: _showsFocus, value: widget.value),
        ),
      ),
    );
  }
}

/// The whole row tappable and at least 56 tall. Announced as one switch named by [title].
final class GPSwitchRow extends StatefulWidget {
  const GPSwitchRow({super.key, this.subtitle, required this.title, required this.value, required this.onChanged});

  final String? subtitle;
  final String title;
  final bool value;
  final void Function(bool value)? onChanged;

  @override
  State<GPSwitchRow> createState() => _GPSwitchRowState();
}

final class _GPSwitchRowState extends State<GPSwitchRow> {
  var _showsFocus = false;

  void _handleToggle() => widget.onChanged?.call(!widget.value);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = widget.onChanged != null;
    final subtitle = widget.subtitle;

    return Semantics(
      toggled: widget.value,
      enabled: enabled,
      label: widget.title,
      hint: subtitle,
      excludeSemantics: true,
      // Excluding the subtree drops the gesture's tap and the detector's focus too: without these a screen reader could not toggle the row.
      onTap: enabled ? _handleToggle : null,
      focusable: enabled,
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (value) => setState(() => _showsFocus = value),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _handleToggle())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _handleToggle : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56.0),
            child: Row(
              spacing: context.spacing.md,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: context.spacing.xxs,
                    children: [
                      Text(widget.title, style: context.text.bodyLarge.copyWith(color: enabled ? colors.onBackground : colors.onSurfaceVariant)),
                      if (subtitle != null) Text(subtitle, style: context.text.bodySmall.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
                GPSwitchTrack(enabled: enabled, showFocus: _showsFocus, value: widget.value),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The painted part only; no gesture, focus or semantics.
final class GPSwitchTrack extends StatelessWidget {
  const GPSwitchTrack({super.key, required this.enabled, this.showFocus = false, required this.value});

  final bool enabled;
  final bool showFocus;
  final bool value;

  static const size = Size(52.0, 32.0);

  /// Off carries a 2px onSurfaceVariant edge: the fill alone is under the 3:1 a control's boundary owes the ground.
  ({Color check, Color edge, Color thumb, Color track}) _paintFor(GPColors colors) => switch ((value, enabled)) {
    (true, true) => (check: colors.primary, edge: Colors.transparent, thumb: colors.onPrimary, track: colors.primary),
    (false, true) => (check: Colors.transparent, edge: colors.onSurfaceVariant, thumb: colors.onSurfaceVariant, track: colors.surfaceVariant),
    (true, false) => (check: colors.onSurfaceVariant, edge: Colors.transparent, thumb: colors.surface, track: colors.outline),
    (false, false) => (check: Colors.transparent, edge: colors.outline, thumb: colors.outline, track: colors.surfaceVariant),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final paint = _paintFor(colors);
    final thumbSize = value ? 24.0 : 16.0;
    final inset = (size.height - thumbSize) / 2;

    return AnimatedContainer(
      duration: GPDurationTokens.normal,
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: paint.track,
        borderRadius: context.radii.borderFull,
        border: Border.all(color: paint.edge, width: 2.0),
        boxShadow: showFocus ? focusRingShadows(gap: colors.background, ring: colors.accentInk) : const [],
      ),
      child: Stack(
        children: [
          AnimatedPositionedDirectional(
            duration: GPDurationTokens.normal,
            curve: Curves.easeOut,
            // The border already takes 2 of the inset.
            start: (value ? size.width - thumbSize - inset : inset) - 2.0,
            top: inset - 2.0,
            width: thumbSize,
            height: thumbSize,
            child: AnimatedContainer(
              duration: GPDurationTokens.normal,
              decoration: BoxDecoration(color: paint.thumb, shape: BoxShape.circle),
              child: AnimatedOpacity(
                opacity: value ? 1.0 : 0.0,
                duration: GPDurationTokens.fast,
                child: Icon(Icons.check, size: 16.0, color: paint.check),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
