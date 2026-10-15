import 'package:flutter/material.dart';
import 'package:ghpockit/core/theme/colors.dart';
import 'package:ghpockit/core/theme/theme_context.dart';
import 'package:ghpockit/core/theme/tokens/dimensions.dart';
import 'package:ghpockit/core/widgets/focus_ring.dart';

/// 52×32, under the 48 touch target in height: prefer [GPSwitchRow], which makes the whole row the target.
class GPSwitch extends StatefulWidget {
  const GPSwitch({required this.value, required this.onChanged, this.semanticLabel, this.autofocus = false, super.key});

  final bool value;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;

  final String? semanticLabel;
  final bool autofocus;

  @override
  State<GPSwitch> createState() => _GPSwitchState();
}

class _GPSwitchState extends State<GPSwitch> {
  bool _showFocus = false;

  void _toggle() => widget.onChanged?.call(!widget.value);

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
        onShowFocusHighlight: (bool value) => setState(() => _showFocus = value),
        actions: <Type, Action<Intent>>{ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _toggle())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _toggle : null,
          child: GPSwitchTrack(value: widget.value, enabled: enabled, showFocus: _showFocus),
        ),
      ),
    );
  }
}

/// A switch with a title and an optional subtitle, the whole row tappable and at least 56 tall. Announced as one switch named by [title].
class GPSwitchRow extends StatefulWidget {
  const GPSwitchRow({required this.title, required this.value, required this.onChanged, this.subtitle, super.key});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<GPSwitchRow> createState() => _GPSwitchRowState();
}

class _GPSwitchRowState extends State<GPSwitchRow> {
  bool _showFocus = false;

  void _toggle() => widget.onChanged?.call(!widget.value);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = widget.onChanged != null;

    return Semantics(
      toggled: widget.value,
      enabled: enabled,
      label: widget.title,
      hint: widget.subtitle,
      excludeSemantics: true,
      // Excluding the subtree drops the gesture's tap and the detector's focus too: without these a screen reader could not toggle the row.
      onTap: enabled ? _toggle : null,
      focusable: enabled,
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (bool value) => setState(() => _showFocus = value),
        actions: <Type, Action<Intent>>{ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _toggle())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _toggle : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(widget.title, style: context.text.bodyLarge.copyWith(color: enabled ? colors.onBackground : colors.onSurfaceVariant)),
                      if (widget.subtitle != null) ...<Widget>[
                        SizedBox(height: context.spacing.xxs),
                        Text(widget.subtitle!, style: context.text.bodySmall.copyWith(color: colors.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: context.spacing.md),
                GPSwitchTrack(value: widget.value, enabled: enabled, showFocus: _showFocus),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The painted part only; no gesture, focus or semantics.
class GPSwitchTrack extends StatelessWidget {
  const GPSwitchTrack({required this.value, required this.enabled, this.showFocus = false, super.key});

  static const Size size = Size(52, 32);

  final bool value;
  final bool enabled;
  final bool showFocus;

  /// Off carries a 2px onSurfaceVariant edge: the fill alone is under the 3:1 a control's boundary owes the ground.
  ({Color track, Color edge, Color thumb, Color check}) _paint(GPColors colors) => switch ((value, enabled)) {
    (true, true) => (track: colors.primary, edge: Colors.transparent, thumb: colors.onPrimary, check: colors.primary),
    (false, true) => (track: colors.surfaceVariant, edge: colors.onSurfaceVariant, thumb: colors.onSurfaceVariant, check: Colors.transparent),
    (true, false) => (track: colors.outline, edge: Colors.transparent, thumb: colors.surface, check: colors.onSurfaceVariant),
    (false, false) => (track: colors.surfaceVariant, edge: colors.outline, thumb: colors.outline, check: Colors.transparent),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final paint = _paint(colors);
    final thumbSize = value ? 24.0 : 16.0;
    final inset = (size.height - thumbSize) / 2;

    return AnimatedContainer(
      duration: GPDurationTokens.normal,
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: paint.track,
        borderRadius: context.radii.borderFull,
        border: Border.all(color: paint.edge, width: 2),
        boxShadow: showFocus ? focusRingShadows(ring: colors.accentInk, gap: colors.background) : const <BoxShadow>[],
      ),
      child: Stack(
        children: <Widget>[
          AnimatedPositionedDirectional(
            duration: GPDurationTokens.normal,
            curve: Curves.easeOut,
            // The border already takes 2 of the inset.
            start: (value ? size.width - thumbSize - inset : inset) - 2,
            top: inset - 2,
            width: thumbSize,
            height: thumbSize,
            child: AnimatedContainer(
              duration: GPDurationTokens.normal,
              decoration: BoxDecoration(color: paint.thumb, shape: BoxShape.circle),
              child: AnimatedOpacity(
                opacity: value ? 1 : 0,
                duration: GPDurationTokens.fast,
                child: Icon(Icons.check, size: 16, color: paint.check),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
